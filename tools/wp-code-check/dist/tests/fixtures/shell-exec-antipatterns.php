<?php

// Intentional anti-patterns for shell_exec/exec/system/passthru Tier 1 rule

function bad_shell_exec_from_input() {
    $cmd = $_GET['cmd'];
    shell_exec($cmd);
}

function bad_exec_for_image_convert($filename) {
    // Even seemingly legitimate uses should be reviewed
    exec("convert " . $filename);
}

function bad_system_call() {
    system($_POST['command']);
}

function bad_passthru_call($arg) {
    passthru($arg);
}

