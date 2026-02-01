<?php

// Intentional anti-patterns for direct file writes with user-controlled paths

function bad_file_put_contents_from_get() {
    $content = "example";
    // Path comes directly from $_GET
    file_put_contents($_GET['file'], $content);
}

function bad_fopen_from_post() {
    // Path comes directly from $_POST
    $path = $_POST['path'];
    $handle = fopen($path, 'w');
    fwrite($handle, "data");
}

function bad_move_uploaded_file_dest_from_get() {
    $tmp  = $_FILES['upload']['tmp_name'];
    $dest = $_GET['dest'];
    // Destination path comes directly from $_GET
    move_uploaded_file($tmp, $dest);
}

function safe_file_put_contents_constant_path() {
    // This should NOT be flagged by the rule
    file_put_contents(__DIR__ . '/log.txt', 'ok');
}

