# PHP 7.4 → 8.3 Upgrade Skill

Upgrade a legacy PHP 7.4 site to PHP 8.3. Work through each phase in order. Ask the user before making large structural changes (e.g. introducing Composer, changing directory layout). After each phase, report what was found/changed and confirm before proceeding to the next.

> **STOP — before reading a single file or running any grep/analysis:**
> Complete **Step 0** (sync from live server) and the **Pre-flight** (move to `www/`) in full, with their commits, before touching Phase 1. Do not read code, scan for patterns, or begin reconnaissance until both steps are done and the user has confirmed.

---

## Step 0 — Sync from live server

Before touching anything, make sure the repo reflects the current state of the live site. Prompt the user:

> "Before we start, please download all files from the live server into this folder so we're working from the latest version — not a stale local copy. This includes any uploaded media, config files, or anything else that may have changed on the server since the last commit. Let me know when that's done."

Once the user confirms the files are downloaded:

1. Run `git status` to see the full picture — pay attention to untracked (`??`) entries, especially large folders and config files.

2. **Before staging anything**, add the following patterns to `.gitignore` (if not already present):
   ```
   # Credentials & secrets
   .env
   *.env
   # Certificates & keys
   *.crt
   *.key
   *.pem
   *.p12
   *.pfx
   # Large media / uploads (exception: keep security .htaccess)
   uploads/*
   !uploads/.htaccess
   www/uploads/*
   !www/uploads/.htaccess
   images/uploads/
   cache/
   tmp/
   ```
   Also ask the user whether any project-specific credential config files (e.g. `config/db.php`, `includes/config.php`) arrived from the server and should be added to `.gitignore` rather than committed.

3. Run `git status` again to confirm those files and folders are now ignored before touching `git add`.

4. **Only stage files that were already tracked** (modified files — `M` in git status):
   ```
   git add -u
   ```
   > **Never use `git add .` or `git add -A` after a server sync.** New untracked files (`??`) have not been vetted — they may contain credentials, certificates, or large binaries. Use `git add -u` to stage only what was already in the index, then explicitly review each remaining untracked file.

5. For any remaining untracked files, decide one by one:
   - Sensitive, binary, or media file → verify it is already covered by `.gitignore` (if not, add it)
   - Genuinely new source file that belongs in the repo → ask the user explicitly before staging

6. Commit with the exact message:
   ```
   Downloaded live server files
   ```

---

## Pre-flight — www/ folder structure

Before Phase 1, check whether the site files are already inside a `www/` subfolder.

**If they are not**, offer to move everything there:
> "Your site files are currently at the repo root. I'd like to move them all into a `www/` subfolder so the root stays clean for Docker files, the database dump, and git config. The `www/` folder will also be the self-contained unit you copy to the server. Shall I do this now?"

If the user agrees, use `git mv` for all tracked site files so history is preserved. Anything not tracked by git should be moved with normal file operations. After the move the repo root should contain only:
- `Dockerfile`
- `docker-compose.yml`
- `docker/`
- `sql_data/`
- `.gitignore`
- `.env.example`

Everything the site needs to run (PHP files, assets, `.env`, vendor libraries) lives inside `www/`.

Once the move is done, stage and commit with the exact message:
```
Move to www folder
```

---

## Phase 1 — Reconnaissance

Before touching any code, map the site:

1. Identify the framework (UserSpice, Laravel, CodeIgniter, vanilla, etc.) and note its version. Check if a newer version exists — if the upgrade is a full rewrite (like UserSpice 4→6), **do not upgrade the framework**, just fix the code in place.
2. Find all hardcoded credentials: DB host/name/user/password, API keys, SMTP passwords, cookie names, reCAPTCHA/Stripe keys. Note the files and line numbers.
3. Find the entry point (`index.php`, `init.php`, bootstrap file) — this is where the `.env` load must go.
4. Check if Composer is already used (`vendor/autoload.php`, `composer.json`). If PHPMailer is bundled as raw files, it must be replaced with Composer.
5. Scan for these PHP 7.4 → 8.x breaking patterns (use Grep across `*.php`):
   - `MYSQL_ASSOC`, `MYSQL_NUM`, `MYSQL_BOTH` — removed constants
   - `$str{$i}` — curly-brace string offsets (removed in 8.0)
   - `implements Serializable` — deprecated in 8.1
   - `http_build_query($p, null,` — null second arg deprecated in 8.0
   - `stripslashes(` — check if null can be passed (deprecated in 8.1)
   - `function ClassName(` — PHP 4-style constructors (removed in 8.0)
   - `function __autoload(` — removed in 8.0, even inside dead `else` branches — PHP 8 fatal-errors on parse
   - `$_POST['key']` / `$_GET['key']` without `??` — undefined index promoted from Notice to Warning in 8.0, which corrupts JSON responses if `display_errors` is On
   - String arithmetic: `$stringVar * $intVar` — TypeError in 8.0 (no implicit coercion)
   - `is_null($result->results()[0])` or `isset($arr[0])` on DB result arrays — accessing index 0 of empty array generates Warning in 8.0
   - Dynamic property assignment on objects without declared properties — deprecated in 8.2
   - `new PHPMailer` without namespace — if using bundled PHPMailer
   - **Auth-gated object access without guard**: `$user->data()->` (or any chained call on an auth object) at file scope in include files without a preceding `isLoggedIn()` check — crashes "Attempt to read property on null" for guests:
     ```bash
     grep -rn "->data()->" www/includes/ --include="*.php"
     ```
   - **OAuth callback files with unguarded array keys**: `$userProfile['locale']` etc. without `?? null` — third-party APIs (Google, etc.) silently drop optional fields in newer API versions, turning a Notice into a Warning that breaks the callback flow in PHP 8

Report a full list of all findings before proceeding.

---

## Phase 2 — Environment & Credentials

Move all hardcoded credentials to a `.env` file inside `www/`:

1. Create `www/.env` — this file lives alongside the site code and is the single source of credentials for both PHP and Docker.
2. Create `.env.example` at the **repo root** (tracked in git) with placeholder values for all variables, so anyone cloning the repo knows what to fill in.
3. Add to `.gitignore`: `www/.env`, `www/vendor/`.
4. Modify the bootstrap/init file to load `www/.env` before any credentials are used. Use `DOCUMENT_ROOT` (which points to `www/`) as the base path. Skip variables already set in the environment so Docker-injected overrides (e.g. `DB_HOST=db`) take precedence over file values:
   ```php
   $_env_file = rtrim($abs_us_root, '/\\') . DIRECTORY_SEPARATOR . '.env';
   if (file_exists($_env_file)) {
       foreach (file($_env_file, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) as $_line) {
           if (str_starts_with(trim($_line), '#') || !str_contains($_line, '=')) continue;
           [$_k, $_v] = explode('=', $_line, 2);
           $_k = trim($_k);
           if (getenv($_k) === false) {
               putenv($_k . '=' . trim($_v));
           }
       }
   }
   ```
5. Replace all hardcoded credentials with `getenv('VAR_NAME')`.
6. Block `.env` access in `www/.htaccess` — the file stays inside the web root but Apache denies any HTTP request for it:
   ```apache
   <FilesMatch "^\.env">
       Require all denied
   </FilesMatch>
   ```

**`.env` variable layout** — include both the PHP-side names and the MariaDB names so Docker can use a single file for both services:
```
# PHP app
DB_HOST=localhost
DB_NAME=mydb
DB_USERNAME=myuser
DB_PASSWORD=mypassword

# OAuth / keys
RECAPTCHA_PRIVATE_KEY=
RECAPTCHA_PUBLIC_KEY=
STRIPE_TEST_SECRET=
STRIPE_TEST_PUBLIC=
STRIPE_LIVE_SECRET=
STRIPE_LIVE_PUBLIC=
COOKIE_NAME=change_this

# MariaDB container (same values, different names)
MYSQL_DATABASE=mydb
MYSQL_USER=myuser
MYSQL_PASSWORD=mypassword
MYSQL_ROOT_PASSWORD=changeme
```

---

## Phase 3 — Docker Setup

Ask the user for the domain they want to use for local testing (e.g. `mysite.net`). They will need to add it to their hosts file — remind them:

> "Add this line to your hosts file so the domain resolves locally:
> `127.0.0.1  <domain>`
> On Windows: `C:\Windows\System32\drivers\etc\hosts` (open as administrator)
> On Mac/Linux: `/etc/hosts`
> This lets you test under real conditions including OAuth callbacks."

Use the domain throughout the Docker config below.

**`Dockerfile`** — check which extensions are already bundled in `php:8.3-apache` before installing (`curl` and `mbstring` are bundled; trying to install them fails the build):
```dockerfile
FROM php:8.3-apache
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
RUN apt-get update && apt-get install -y libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-install pdo_mysql mysqli zip \
    && a2enmod rewrite ssl \
    && openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout /etc/ssl/private/localhost.key \
        -out /etc/ssl/certs/localhost.crt \
        -subj "/CN=<domain>" \
        -addext "subjectAltName=DNS:<domain>,DNS:localhost,IP:127.0.0.1" \
        -addext "basicConstraints=CA:FALSE" \
        -addext "keyUsage=digitalSignature,keyEncipherment" \
        -addext "extendedKeyUsage=serverAuth" \
    && apt-get clean && rm -rf /var/lib/apt/lists/*
COPY docker/php.ini /usr/local/etc/php/conf.d/app.ini
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2-foreground"]
```

Note: `docker/apache.conf` is **not** baked into the image — it is mounted as a volume so domain changes don't require a rebuild.

**`docker/php.ini`** — prevents warnings from corrupting JSON API responses:
```ini
display_errors = Off
log_errors = On
error_reporting = E_ALL
error_log = /var/log/apache2/php_errors.log
```

**`docker/apache.conf`** — replace `<domain>` with the actual domain:
```apache
ServerName <domain>
<VirtualHost *:80>
    ServerName <domain>
    ServerAlias localhost
    DocumentRoot /var/www/html/www
    <Directory /var/www/html/www>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
<VirtualHost *:443>
    ServerName <domain>
    ServerAlias localhost
    DocumentRoot /var/www/html/www
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/localhost.crt
    SSLCertificateKeyFile /etc/ssl/private/localhost.key
    <Directory /var/www/html/www>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

**`docker/entrypoint.sh`**:
```bash
#!/bin/bash
set -e
exec "$@"
```

**`docker-compose.yml`** — both services read from `www/.env`; no separate `.env` at the repo root needed:
```yaml
services:
  app:
    build: .
    ports:
      - "80:80"
      - "443:443"
    env_file: ./www/.env
    environment:
      DB_HOST: db
    depends_on:
      db:
        condition: service_healthy
    volumes:
      - ./www:/var/www/html/www
      - ./docker/apache.conf:/etc/apache2/sites-available/000-default.conf:ro

  db:
    image: mariadb:10.11
    env_file: ./www/.env
    volumes:
      - db_data:/var/lib/mysql
      - ./sql_data/<dump_filename>.sql:/docker-entrypoint-initdb.d/init.sql:ro
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 10
    ports:
      - "3306:3306"

volumes:
  db_data:
```

The MariaDB container picks up `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`, and `MYSQL_ROOT_PASSWORD` directly from `env_file` — no `${VAR}` substitution needed in the compose file.

Fix `www/.htaccess` HTTPS redirect so it doesn't loop on the Docker HTTP vhost (HTTP → HTTPS redirect still fires for the real domain, which is correct for OAuth testing):
```apache
RewriteCond %{HTTPS} off
RewriteCond %{HTTP_HOST} !^localhost(:[0-9]+)?$
RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
```

**Docker quick-reference** (no Makefile needed):
```
docker compose up -d          # start
docker compose down           # stop
docker compose down -v        # stop and wipe database volume
docker compose build          # rebuild image
docker compose build --no-cache  # force full rebuild (e.g. after cert domain change)
docker compose logs -f app    # tail app logs
docker compose exec app bash  # shell into app container
docker compose exec app bash -c "cat /var/log/apache2/php_errors.log"
```

**Mailpit — local email catcher**: Docker containers have no MTA. Without one, `mail()` silently drops and PHPMailer throws. Add Mailpit as a standard service:

```yaml
  mailpit:
    image: axllent/mailpit
    ports:
      - "8025:8025"   # web UI at http://localhost:8025
      - "1025:1025"   # SMTP
```

Add to `www/.env`:
```
SMTP_HOST=mailpit
SMTP_PORT=1025
SMTP_USER=
SMTP_PASS=
SMTP_FROM=noreply@yourdomain.com
```

Wire PHPMailer conditionally (no-op on shared hosting where `SMTP_HOST` is unset):
```php
$smtp_host = getenv('SMTP_HOST');
if ($smtp_host) {
    $mail->isSMTP();
    $mail->Host = $smtp_host;
    $mail->Port = (int)(getenv('SMTP_PORT') ?: 25);
    $smtp_user = getenv('SMTP_USER');
    if ($smtp_user) {
        $mail->SMTPAuth   = true;
        $mail->Username   = $smtp_user;
        $mail->Password   = getenv('SMTP_PASS') ?: '';
        $mail->SMTPSecure = \PHPMailer\PHPMailer\PHPMailer::ENCRYPTION_STARTTLS;
    }
}
```

**Trusting the self-signed cert in the browser** (required for OAuth to work locally):
1. `docker compose exec app cat /etc/ssl/certs/localhost.crt > site-local.crt`
2. On Windows: double-click `site-local.crt` → Install Certificate → Local Machine → Trusted Root Certification Authorities
3. On Mac: double-click, add to System keychain, set to Always Trust
4. Restart the browser

---

## Phase 4 — Introduce Composer

If the project uses bundled PHPMailer or other libraries that have Composer packages:

1. Create `www/composer.json`:
   ```json
   {
     "require": {
       "php": ">=8.0",
       "phpmailer/phpmailer": "^6.9"
     },
     "config": {
       "optimize-autoloader": true
     }
   }
   ```
2. Update the bootstrap file: replace any manual `require` of PHPMailer with `require_once $abs_us_root . '/vendor/autoload.php';`
3. Update usage: `new PHPMailer` → `new \PHPMailer\PHPMailer\PHPMailer(true)`

---

## Phase 5 — Fix Breaking Changes

Fix each category of breaking change found in Phase 1. Apply fixes in batches per category.

### 5a — Removed mysql_* constants
If a class uses `MYSQL_ASSOC` or `MYSQL_NUM` as default parameter values, PHP 8 evaluates them at class-load time → Fatal Error. If the class just wraps `mysqli`, **delete the entire old class** and make the factory always return the `mysqli` variant. Do not try to define the constants manually.

### 5b — Curly-brace string offsets
```bash
# Find all occurrences
grep -rn '\$[a-zA-Z_][a-zA-Z0-9_]*{' www/ --include="*.php"
```
Replace `$str{$i}` → `$str[$i]`.

### 5c — Serializable interface (PHP 8.1)
Replace `implements \Serializable` with magic methods:
```php
// Remove: implements \Serializable
// Remove: public function serialize() { return serialize([...]); }
// Remove: public function unserialize($data) { ... }
// Add:
public function __serialize(): array {
    return ['field1' => $this->field1, 'field2' => $this->field2];
}
public function __unserialize(array $data): void {
    $this->field1 = $data['field1'];
    $this->field2 = $data['field2'];
}
```

### 5d — http_build_query null second arg
```php
// Before:
http_build_query($params, null, $separator)
// After:
http_build_query($params, '', $separator)
```

### 5e — Dynamic properties (PHP 8.2)
If a class assigns `$this->undeclaredProp`, add `public $undeclaredProp;` to the class definition. Find the base class and add the declaration there if it's inherited.

### 5f — stripslashes(null) (PHP 8.1)
Find all calls to `stripslashes()` that receive DB result fields (which may be NULL):
```bash
grep -rn "stripslashes(" www/ --include="*.php" -l
```
Replace: `stripslashes($val)` → `stripslashes($val ?? '')`

### 5g — PHP 4-style constructors (PHP 8.0)
A method named the same as its class is a PHP 4 constructor — removed in PHP 8.0:
```php
// Before:
class ReCaptcha {
    function ReCaptcha($secret) { ... }
}
// After:
class ReCaptcha {
    function __construct($secret) { ... }
}
```

### 5h — __autoload() removed (PHP 8.0)
PHP 8 throws a Fatal Error if `function __autoload()` appears **anywhere in a file**, even inside a dead `else` branch that will never execute. The entire file fails to parse.

Find it with:
```bash
grep -rn "function __autoload" www/ --include="*.php"
```
The typical pattern in old bundled autoloaders:
```php
// This entire else block must be deleted — PHP 8 won't even parse the file
} else {
    function __autoload($classname) {
        PHPMailerAutoload($classname);
    }
}
```
Replace the whole version-branching block with a single `spl_autoload_register` call:
```php
spl_autoload_register('PHPMailerAutoload', true, true);
```

**IMPORTANT — batch file editing on Windows**: When using PowerShell to batch-edit PHP files, NEVER use `Set-Content -Encoding UTF8` — PowerShell 5.1 adds a UTF-8 BOM which PHP outputs before headers, breaking `session_start()`. Always use:
```powershell
$encoding = New-Object System.Text.UTF8Encoding $false  # false = no BOM
[System.IO.File]::WriteAllText($path, $content, $encoding)
```

### 5i — Undefined $_POST/$_GET keys
PHP 8 promotes undefined index from Notice to Warning. With `display_errors = On` this corrupts JSON responses. Fix all unguarded accesses across include files:
```bash
grep -rn "\$_POST\['" www/includes/ --include="*.php" | grep -v "??"
```
Replace: `$_POST['key']` → `$_POST['key'] ?? null` (or `?? ''`, `?? 0` depending on expected type).

This is often hundreds of occurrences. Use a PowerShell batch script (BOM-free) to apply systematically.

### 5j — Undefined array key 0 on empty DB results
A common pattern `is_null($result->results()[0])` generates "Undefined array key 0" when the result set is empty. Replace across all include files:
```powershell
# BOM-free batch replacement
$encoding = New-Object System.Text.UTF8Encoding $false
$files = Get-ChildItem -Path ".\www\includes" -Recurse -Filter "*.php" |
    Select-String -SimpleMatch 'is_null($result->results()[0])' |
    Select-Object -ExpandProperty Path -Unique
foreach ($f in $files) {
    $c = [System.IO.File]::ReadAllText($f)
    $c = $c.Replace('is_null($result->results()[0])', 'empty($result->results())')
    [System.IO.File]::WriteAllText($f, $c, $encoding)
}
```

### 5k — String × int arithmetic
PHP 8 throws `TypeError: Unsupported operand types: string * int` where PHP 7 silently coerced. Common in pagination:
```php
// Before (crashes when $page is a POST string or empty string):
$offset = ($page * $items_per_page) - $items_per_page;

// After (also fixes PHP 8 "" == 0 comparison change):
$page = max(1, (int)($_POST['page'] ?? 1));
$offset = ($page - 1) * $items_per_page;
```
Note: PHP 8 also changed `"" == 0` from `true` to `false`, so loose-comparison guards like `if ($page == 0)` no longer catch empty strings.

### 5l — No-op property self-assignments
If a foreach loop assigns `$obj->prop = $obj->prop` for columns not in the SQL SELECT, remove those lines — they generate "Undefined property" warnings and do nothing.

### 5m — Duplicate INSERT on owner == sub-account
If the code does two separate INSERTs for "owner access" and "user access" with the same ID (main account has `account_owner == 0`, so both IDs are equal), add a guard:
```php
if ($user_id != $owner_id) {
    // second INSERT
}
```

### 5n — Auth-gated object access without guard
Include files that call `$user->data()->id` at the top of the file (to get the logged-in user's ID for queries) crash with "Attempt to read property on null" when a guest visits. The variable is also often unused — the query below doesn't reference it.

Fix: remove the line if unused, or guard it:
```php
// If user_id is actually needed in the query:
$user_id = $user->isLoggedIn() ? $user->data()->id : null;
if (!$user_id) { echo json_encode(null); exit; }
```

---

## Phase 6 — Security Hardening

Apply after all breaking changes are fixed and the site loads cleanly. Do this before deploy.

### 6a — PDO hardening
In the DB class constructor:
- Add `charset=utf8mb4` to the DSN string
- Add `PDO::ATTR_EMULATE_PREPARES => false` (forces real prepared statements, enables proper type handling)
- Add `PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION`
- Replace `die($e->getMessage())` with `error_log(...)` + a generic user-facing message — prevents DB credentials and schema details leaking to the browser

### 6b — SQL injection audit
Grep for queries built with string concatenation and user-supplied variables:
```bash
grep -rn "WHERE.*\$_\|WHERE.*\\\$[a-z]" www/ --include="*.php"
```
Replace every concatenated query with PDO parameterized queries (`?` placeholders). Pay special attention to OAuth `checkUser()` methods — they commonly have multiple UPDATE/INSERT statements with direct variable interpolation.

Also watch for: hardcoded user IDs in UPDATE statements (`WHERE id = 3`), wrong SQL syntax order (`UPDATE table WHERE ... SET ...` instead of `UPDATE table SET ... WHERE ...`).

### 6c — XSS: escape all output
Any value from user input or a DB column echoed into HTML must be wrapped:
```php
echo htmlspecialchars($value, ENT_QUOTES | ENT_HTML5, 'UTF-8');
```
Priority targets: page `<title>`, meta description, og: tags, any `echo $result->field` in page headers.

### 6d — PHPMailer: fix open relay + validate inputs
1. **Open relay**: Never use `$mail->setFrom($email)` where `$email` is user-submitted. Use a fixed system address as From, add the user's address as ReplyTo:
   ```php
   $mail->setFrom(getenv('SMTP_FROM'), 'Website Contact');
   $mail->addReplyTo($email, $name);
   ```
2. **Email validation**: `if (!filter_var($email, FILTER_VALIDATE_EMAIL)) { /* reject */ }`
3. **Input sanitization**: `strip_tags(trim($name))` on all text fields before use
4. **File upload MIME whitelist** (if the form accepts attachments): use `finfo_file()` to check the actual MIME type, enforce a max size (e.g. 2 MB), and whitelist only safe types (`image/jpeg`, `image/png`, `image/gif`, `application/pdf`)

### 6e — Session cookie hardening
Do this in PHP code, not `php.ini`, so `cookie_secure` can be conditional (localhost is HTTP, production is HTTPS — setting it unconditionally in php.ini breaks the Docker dev environment):
```php
$_is_https = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off')
          || (!empty($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https');
session_start([
    'cookie_httponly' => true,
    'cookie_secure'   => $_is_https,
    'cookie_samesite' => 'Lax',
]);
unset($_is_https);
```

### 6f — PHP ini additions
Add to `docker/php.ini` (and production `php.ini` / `.user.ini`):
```ini
expose_php = Off
session.use_strict_mode = 1
allow_url_include = Off
output_buffering = On
```

### 6g — HTTP security headers + Apache server tokens
Add to `www/.htaccess` (requires `mod_headers` — add `headers` to the `a2enmod` line in Dockerfile):
```apache
<IfModule mod_headers.c>
    Header always set X-Frame-Options "SAMEORIGIN"
    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set Permissions-Policy "geolocation=(), microphone=(), camera=()"
    Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" env=HTTPS
</IfModule>
```

Add to `docker/apache.conf` at top level (outside `<VirtualHost>`):
```apache
ServerTokens Prod
ServerSignature Off
```

### 6h — Block Composer files and vendor/ from web
Add to `www/.htaccess`:
```apache
<FilesMatch "^composer\.(json|lock)$">
    Require all denied
</FilesMatch>
RewriteRule ^vendor/ - [F,L]
```

### 6i — Protect uploads directory
Create `www/uploads/.htaccess`:
```apache
<FilesMatch "\.php">
    Require all denied
</FilesMatch>
Options -ExecCGI
```

This file must be tracked in git despite uploads being gitignored — use the exception pattern from Step 0 (`uploads/*` + `!uploads/.htaccess`).

---

## Phase 7 — Verify

1. Start the stack: `docker compose up -d`
2. Check PHP errors: `docker compose exec app bash -c "cat /var/log/apache2/php_errors.log"`
3. Open `https://<domain>` in the browser — login should work, session should persist.
4. Exercise each major feature: list views, search/filter with pagination, create/edit/delete records, file uploads, OAuth login.
5. Check the browser Network tab for any 500 responses or JSON parse errors.
6. Fix any remaining errors found in the log — they will typically be one of the patterns from Phase 5.

---

## Phase 8 — Deploy to Production

The `www/` folder is self-contained and ready to upload:

1. Copy `www/` to your server's document root via FTP, SFTP, or rsync. Exclude `.env` (never committed) and `vendor/` (must be regenerated on the server):
   ```
   rsync -avz --exclude='.env' --exclude='vendor/' www/ user@server:/path/to/public_html/
   ```
2. On the server, run Composer to install production dependencies:
   ```
   composer install --no-dev --optimize-autoloader
   ```
3. On the server, manually create `/path/to/public_html/.env` with production credentials. This file is never committed to git and is already blocked from web access by `.htaccess`.
4. Verify `.htaccess` is blocking `.env`: `curl -I https://yourdomain.com/.env` should return 403.

---

## Key Lessons from Real Upgrade Experience

- **BOM kills sessions**: PowerShell 5.1 `Set-Content -Encoding UTF8` writes a BOM. PHP outputs it before headers → `session_start()` fails → all authenticated endpoints return "login". Always use `UTF8Encoding($false)`.
- **`display_errors = Off` first**: Turn it off in `docker/php.ini` before debugging API endpoints — otherwise PHP warnings are injected into JSON responses and the JS can't parse them.
- **`__autoload()` is a parse-time fatal**: PHP 8 refuses to load any file that defines `function __autoload()`, even inside a dead `else` branch. The entire file is unparseable. Delete the branch, don't try to guard it.
- **curl and mbstring are bundled in php:8.3-apache**: Running `docker-php-ext-install curl mbstring` fails the build. Check which extensions are already present with `docker run --rm php:8.3-apache php -m` before adding to the install list.
- **MYSQL_USER=root is ignored by MariaDB Docker**: If `MYSQL_USER` is set to `root`, the image ignores it — root is created only via `MYSQL_ROOT_PASSWORD`. Use a non-root username for `DB_USERNAME`/`MYSQL_USER`.
- **Docker env_file overrides need a guard**: If both Docker `environment:` and a loaded `.env` file set the same key, the `.env` loader will overwrite Docker's value unless you check `getenv($k) === false` before calling `putenv()`.
- **Mount apache.conf as a volume**: Baking it into the image means a full rebuild every time you change a domain or alias. Mount it with `:ro` instead and just restart the container.
- **Empty string ≠ zero in PHP 8**: `"" == 0` was `true` in PHP 7, `false` in PHP 8. Pagination and other numeric guards using `== 0` must be rewritten with explicit `(int)` casting.
- **Don't upgrade incompatible frameworks**: If the framework's own upgrade is a full rewrite (e.g. UserSpice 4→6), skip it and just fix the 7.4 code in place.
- **Bundled third-party libraries**: Old bundled copies of Google API client, Facebook SDK etc. may have their own PHP 8 issues (curly-brace offsets, null params). Patch them in-place rather than upgrading the whole library, unless there's a clean Composer path.
- **CRLF files and PowerShell**: Files with Windows CRLF line endings won't match LF patterns in PowerShell here-strings. Normalize with `-replace "\`r\`n", "\`n"` before string matching.
- **Dump filename must match**: Docker creates a directory at the mount path if the target file doesn't exist yet. Always confirm the actual filename in `sql_data/` and set the volume mount accordingly before first `docker compose up`.
- **Docker has no mail transport**: `mail()` silently drops; PHPMailer throws. Add Mailpit to docker-compose and configure PHPMailer via SMTP env vars. Use a conditional check (`if ($smtp_host)`) so the same code works on shared hosting where `SMTP_HOST` is unset.
- **`cookie_secure` must be conditional in PHP**: Setting it to `1` in `php.ini` breaks localhost HTTP. Detect HTTPS at runtime via `$_SERVER['HTTPS']` and `HTTP_X_FORWARDED_PROTO`, then pass to `session_start()`.
- **OAuth API fields can disappear**: Google removed `locale` from the standard profile response. Guard all optional OAuth callback fields with `?? null` — their absence generates a PHP 8 Warning that breaks the entire callback flow.
