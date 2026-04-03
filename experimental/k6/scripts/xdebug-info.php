<?php
header('Content-Type: application/json');
echo json_encode([
    'php_ini' => php_ini_loaded_file(),
    'xdebug.mode' => ini_get('xdebug.mode'),
    'xdebug.start_with_request' => ini_get('xdebug.start_with_request'),
    'xdebug.output_dir' => ini_get('xdebug.output_dir'),
    'xdebug.profiler_output_name' => ini_get('xdebug.profiler_output_name'),
], JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES), "\n";

