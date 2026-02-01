<?php

// BAD: eval on variable from POST
function bad_eval_from_post() {
    $code = $_POST['snippet'];
    eval($code);
}

// BAD: eval on decoded payload from GET
function bad_eval_from_get() {
    $payload = base64_decode($_GET['payload']);
    eval($payload);
}

// BAD: dynamic include from superglobal
function bad_dynamic_include_query() {
    include $_GET['page'] . '.php';
}

// BAD: dynamic require from variable
function bad_dynamic_require_template() {
    $template = $_POST['template'];
    require $template;
}

// GOOD: static include (should not be flagged by dynamic include pattern)
function good_static_include() {
    include __DIR__ . '/views/admin-page.php';
}

