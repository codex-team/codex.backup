<?php

# Yandex fix for outdated php
if (!function_exists('curl_reset'))
{
    function curl_reset(&$ch)
    {
        $ch = curl_init();
    }
}

include 'settings.php';
require_once 'phar://yandex-php-library_master.phar/vendor/autoload.php';

use Yandex\Disk\DiskClient;

if(!defined('API_TOKEN')) die('API_TOKEN not defined.\n');

function upload_backup($backup_name, $backup_type='.sql', $prefix='')
{
    $diskClient = new DiskClient(API_TOKEN);
    $diskClient->setServiceScheme(DiskClient::HTTPS_SCHEME);

    $diskClient->uploadFile(
        '/backups/',
        array(
            'path' => $backup_name,
            'size' => filesize($backup_name),
            'name' => $prefix . 'codex_backup_'.microtime(true). $backup_type
        )
    );
}

if (count($argv) == 4) {
    if (file_exists($argv[1]))
        upload_backup($argv[1], $argv[2], $argv[3]);
    else
        echo "File not found: " . $argv[1] . "\n";
} else {
    echo "Invalid params count.\n\nUsage: php backup.php filename.sql\n";
}

?>