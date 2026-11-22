<?php
/**
 * Copy this to config.php on the server and fill in the real values.
 *
 * config.php is gitignored and must stay that way: these credentials give
 * full read/write access to the accounts table. They live on the server
 * only — never in the repository, and never inside the APK, where anyone
 * who decompiled it would gain the same access.
 */
return [
    // Hostinger puts MySQL on the same machine as PHP, so this stays
    // 'localhost'. That is the whole point of running the API here: the
    // app never connects to MySQL itself, so remote MySQL access — and
    // the plan tier that reportedly gates it — is not needed at all.
    'host' => 'localhost',
    'port' => 3306,

    // hPanel prefixes both with your account id, e.g. u123456789_huni_db.
    'name' => 'uXXXXXXXXX_huni_db',
    'user' => 'uXXXXXXXXX_huni',
    'pass' => '',
];
