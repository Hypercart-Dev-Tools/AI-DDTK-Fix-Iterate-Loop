#!/usr/bin/env php
<?php
/**
 * Golden Rules Analyzer
 *
 * A lightweight static analysis tool for WordPress/PHP codebases that enforces
 * six core principles to prevent "vibe coding drift" — where AI-assisted or
 * rapid development introduces patterns that bypass established conventions.
 *
 * Part of the WP Code Check toolkit by Hypercart.
 *
 * =============================================================================
 * GOAL STATEMENT
 * =============================================================================
 *
 * Catch the antipatterns that pass code review but bite you in production.
 * This is NOT a replacement for PHPStan or PHPCS — it's a complement that
 * catches project-level architectural drift that generic tools miss.
 *
 * =============================================================================
 * BACKGROUND & CONTEXT
 * =============================================================================
 *
 * Why this exists:
 * - PHPStan catches type errors, not architectural violations
 * - PHPCS catches style issues, not duplicate functionality
 * - Neither catches unbounded queries, state mutation bypasses, or truth duplication
 *
 * The 6 Golden Rules:
 * 1. Search before you create — The function you need probably exists
 * 2. State flows through gates — Never mutate state directly
 * 3. One truth, one place — Reference data, don't copy it
 * 4. Queries have boundaries — Every database call has a LIMIT
 * 5. Fail gracefully — Assume it will break
 * 6. Ship clean — Debug code is for debugging
 *
 * Coverage vs existing tools:
 * - Rule 1 (duplication): NOT covered by PHPStan/PHPCS
 * - Rule 2 (state gates): NOT covered — too project-specific
 * - Rule 3 (single truth): NOT covered
 * - Rule 4 (query limits): PARTIAL in WPCS (flags query_posts, not missing LIMIT)
 * - Rule 5 (error handling): PARTIAL in PHPStan at level 6+
 * - Rule 6 (debug code): COVERED by WPCS WordPress.PHP.DevelopmentFunctions
 *
 * =============================================================================
 * USAGE
 * =============================================================================
 *
 * Basic:
 *   php golden-rules-analyzer.php /path/to/plugin
 *
 * With options:
 *   php golden-rules-analyzer.php /path/to/plugin --rule=queries --format=json
 *
 * Pre-commit hook (.husky/pre-commit or .git/hooks/pre-commit):
 *   php golden-rules-analyzer.php . --staged-only --fail-on=error
 *
 * GitHub Actions:
 *   - run: php golden-rules-analyzer.php . --format=github
 *
 * =============================================================================
 * CONFIGURATION
 * =============================================================================
 *
 * Create .golden-rules.json in project root:
 * {
 *   "state_handlers": ["set_state", "transition_to", "update_status"],
 *   "state_properties": ["$this->state", "$this->status", "$this->current_state"],
 *   "helper_classes": ["Helper", "Utils", "Utilities"],
 *   "ignore_paths": ["vendor/", "node_modules/", "tests/"],
 *   "severity_threshold": "warning"
 * }
 *
 * @package    Hypercart
 * @subpackage WP_Code_Check
 * @author     Hypercart
 * @copyright  2025 Hypercart (a DBA of Neochrome, Inc.)
 * @license    Apache-2.0
 * @version    1.0.0
 * @link       https://github.com/Hypercart-Dev-Tools/WP-Code-Check
 */

declare(strict_types=1);

namespace Hypercart\WPCodeCheck\GoldenRules;

/**
 * Violation severity levels.
 */
class Severity {
    public const ERROR   = 'error';
    public const WARNING = 'warning';
    public const INFO    = 'info';
}

/**
 * Represents a single rule violation.
 */
class Violation {
    public function __construct(
        public readonly string $rule,
        public readonly string $file,
        public readonly int $line,
        public readonly string $message,
        public readonly string $severity = Severity::WARNING,
        public readonly ?string $suggestion = null,
        public readonly ?string $code_snippet = null
    ) {}

    public function toArray(): array {
        return [
            'rule'       => $this->rule,
            'file'       => $this->file,
            'line'       => $this->line,
            'message'    => $this->message,
            'severity'   => $this->severity,
            'suggestion' => $this->suggestion,
            'snippet'    => $this->code_snippet,
        ];
    }
}

/**
 * Configuration loader and holder.
 */
class Config {
    public array $state_handlers = [
        'set_state',
        'transition_to', 
        'transition',
        'update_status',
        'change_state',
        'setState',
    ];

    public array $state_properties = [
        '$this->state',
        '$this->status', 
        '$this->current_state',
        '$this->workflow_state',
        'self::$state',
    ];

    public array $helper_classes = [
        'Helper',
        'Helpers', 
        'Utils',
        'Utilities',
        'Util',
    ];

    public array $ignore_paths = [
        'vendor/',
        'node_modules/',
        'tests/',
        '.git/',
    ];

    public array $debug_functions = [
        'var_dump',
        'print_r',
        'error_log',
        'debug_print_backtrace',
        'var_export',
        'dd',        // Laravel/common debug
        'dump',      // Symfony/common debug
        'ray',       // Spatie Ray
    ];

    public string $severity_threshold = Severity::INFO;

    public static function load(string $project_root): self {
        $config = new self();
        $config_file = rtrim($project_root, '/') . '/.golden-rules.json';

        if (file_exists($config_file)) {
            $json = json_decode(file_get_contents($config_file), true);
            if (is_array($json)) {
                foreach ($json as $key => $value) {
                    if (property_exists($config, $key)) {
                        $config->$key = $value;
                    }
                }
            }
        }

        return $config;
    }
}

/**
 * Base class for rule analyzers.
 */
abstract class Rule {
    protected Config $config;

    public function __construct(Config $config) {
        $this->config = $config;
    }

    abstract public function getName(): string;
    abstract public function getDescription(): string;
    abstract public function analyze(string $file, string $content, array $tokens): array;

    protected function getLineNumber(string $content, int $position): int {
        return substr_count(substr($content, 0, $position), "\n") + 1;
    }

    protected function getCodeSnippet(string $content, int $line, int $context = 2): string {
        $lines = explode("\n", $content);
        $start = max(0, $line - $context - 1);
        $end = min(count($lines), $line + $context);
        
        $snippet = [];
        for ($i = $start; $i < $end; $i++) {
            $marker = ($i === $line - 1) ? '>' : ' ';
            $snippet[] = sprintf('%s %4d | %s', $marker, $i + 1, $lines[$i]);
        }
        
        return implode("\n", $snippet);
    }
}

/**
 * Rule 1: Search before you create
 * Detects potential duplicate function implementations.
 */
class DuplicationRule extends Rule {
    private array $known_functions = [];
    private array $function_signatures = [];

    public function getName(): string {
        return 'duplication';
    }

    public function getDescription(): string {
        return 'Search before you create — The function you need probably exists';
    }

    public function analyze(string $file, string $content, array $tokens): array {
        $violations = [];
        
        // Extract functions from this file
        $functions = $this->extractFunctions($content, $tokens);
        
        foreach ($functions as $func) {
            // Check for similar function names
            $similar = $this->findSimilarFunctions($func['name']);
            if (!empty($similar)) {
                $violations[] = new Violation(
                    rule: $this->getName(),
                    file: $file,
                    line: $func['line'],
                    message: sprintf(
                        'Function "%s" may duplicate existing functionality',
                        $func['name']
                    ),
                    severity: Severity::WARNING,
                    suggestion: sprintf(
                        'Check these similar functions: %s',
                        implode(', ', array_slice($similar, 0, 3))
                    ),
                    code_snippet: $this->getCodeSnippet($content, $func['line'])
                );
            }

            // Check if function is in a Helper class but duplicates non-Helper
            if ($this->isInHelperClass($file)) {
                // This is fine - Helper classes are expected to consolidate
            } else {
                // Check if a Helper class has similar functionality
                $helper_match = $this->findInHelperClasses($func['name']);
                if ($helper_match) {
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: $func['line'],
                        message: sprintf(
                            'Function "%s" may already exist in Helper class',
                            $func['name']
                        ),
                        severity: Severity::WARNING,
                        suggestion: sprintf('Check %s', $helper_match),
                        code_snippet: $this->getCodeSnippet($content, $func['line'])
                    );
                }
            }

            // Register this function for cross-file analysis
            $this->registerFunction($file, $func);
        }

        return $violations;
    }

    public function registerKnownFunctions(array $functions): void {
        $this->known_functions = array_merge($this->known_functions, $functions);
    }

    private function extractFunctions(string $content, array $tokens): array {
        $functions = [];
        $count = count($tokens);
        
        for ($i = 0; $i < $count; $i++) {
            if (is_array($tokens[$i]) && $tokens[$i][0] === T_FUNCTION) {
                // Find function name
                for ($j = $i + 1; $j < $count; $j++) {
                    if (is_array($tokens[$j]) && $tokens[$j][0] === T_STRING) {
                        $functions[] = [
                            'name' => $tokens[$j][1],
                            'line' => $tokens[$j][2],
                        ];
                        break;
                    }
                    if ($tokens[$j] === '(') {
                        break; // Anonymous function
                    }
                }
            }
        }

        return $functions;
    }

    private function findSimilarFunctions(string $name): array {
        $similar = [];
        $name_lower = strtolower($name);
        $name_parts = $this->splitFunctionName($name);

        foreach ($this->known_functions as $known) {
            if (strtolower($known['name']) === $name_lower) {
                continue; // Exact match in different file - might be intentional
            }

            $known_parts = $this->splitFunctionName($known['name']);
            $similarity = $this->calculateSimilarity($name_parts, $known_parts);
            
            if ($similarity > 0.7) {
                $similar[] = sprintf('%s (%s)', $known['name'], basename($known['file']));
            }
        }

        return $similar;
    }

    private function splitFunctionName(string $name): array {
        // Split by camelCase and snake_case
        $parts = preg_split('/(?=[A-Z])|_/', $name, -1, PREG_SPLIT_NO_EMPTY);
        return array_map('strtolower', $parts);
    }

    private function calculateSimilarity(array $parts1, array $parts2): float {
        if (empty($parts1) || empty($parts2)) {
            return 0.0;
        }

        $intersection = count(array_intersect($parts1, $parts2));
        $union = count(array_unique(array_merge($parts1, $parts2)));
        
        return $intersection / $union;
    }

    private function isInHelperClass(string $file): bool {
        $filename = basename($file);
        foreach ($this->config->helper_classes as $helper) {
            if (stripos($filename, $helper) !== false) {
                return true;
            }
        }
        return false;
    }

    private function findInHelperClasses(string $name): ?string {
        foreach ($this->known_functions as $known) {
            if ($this->isInHelperClass($known['file'])) {
                $similarity = similar_text(
                    strtolower($name),
                    strtolower($known['name']),
                    $percent
                );
                if ($percent > 70) {
                    return sprintf('%s::%s', basename($known['file']), $known['name']);
                }
            }
        }
        return null;
    }

    private function registerFunction(string $file, array $func): void {
        $this->known_functions[] = [
            'file' => $file,
            'name' => $func['name'],
            'line' => $func['line'],
        ];
    }
}

/**
 * Rule 2: State flows through gates
 * Detects direct state property mutations.
 */
class StateGatesRule extends Rule {
    public function getName(): string {
        return 'state-gates';
    }

    public function getDescription(): string {
        return 'State flows through gates — Never mutate state directly';
    }

    public function analyze(string $file, string $content, array $tokens): array {
        $violations = [];
        
        // Check for direct state property assignments
        foreach ($this->config->state_properties as $prop) {
            $pattern = preg_quote($prop, '/') . '\s*=\s*[^=]';
            
            if (preg_match_all('/' . $pattern . '/m', $content, $matches, PREG_OFFSET_CAPTURE)) {
                foreach ($matches[0] as $match) {
                    $line = $this->getLineNumber($content, $match[1]);
                    $line_content = $this->getLineContent($content, $line);
                    
                    // Check if this is inside a state handler method
                    if (!$this->isInsideStateHandler($content, $match[1])) {
                        $violations[] = new Violation(
                            rule: $this->getName(),
                            file: $file,
                            line: $line,
                            message: sprintf('Direct state mutation detected: %s', trim($line_content)),
                            severity: Severity::ERROR,
                            suggestion: sprintf(
                                'Use a state handler method like: %s',
                                implode(', ', array_slice($this->config->state_handlers, 0, 3))
                            ),
                            code_snippet: $this->getCodeSnippet($content, $line)
                        );
                    }
                }
            }
        }

        return $violations;
    }

    private function getLineContent(string $content, int $line): string {
        $lines = explode("\n", $content);
        return $lines[$line - 1] ?? '';
    }

    private function isInsideStateHandler(string $content, int $position): bool {
        // Find the enclosing function
        $before = substr($content, 0, $position);
        
        foreach ($this->config->state_handlers as $handler) {
            // Check if we're inside a function that matches a handler pattern
            $pattern = '/function\s+' . preg_quote($handler, '/') . '\s*\(/i';
            if (preg_match($pattern, $before)) {
                // Verify the function hasn't closed
                $func_start = strrpos($before, 'function');
                $excerpt = substr($content, $func_start, $position - $func_start);
                $opens = substr_count($excerpt, '{');
                $closes = substr_count($excerpt, '}');
                if ($opens > $closes) {
                    return true;
                }
            }
        }

        // Also allow if the method name contains state-related keywords
        if (preg_match('/function\s+\w*(state|status|transition)\w*\s*\(/i', $before)) {
            return true;
        }

        return false;
    }
}

/**
 * Rule 3: One truth, one place
 * Detects duplicated configuration and magic values.
 */
class SingleTruthRule extends Rule {
    private array $constants = [];
    private array $magic_strings = [];

    public function getName(): string {
        return 'single-truth';
    }

    public function getDescription(): string {
        return 'One truth, one place — Reference data, don\'t copy it';
    }

    public function analyze(string $file, string $content, array $tokens): array {
        $violations = [];
        
        // Detect hardcoded option names that should be constants
        $option_patterns = [
            '/get_option\s*\(\s*[\'"]([^\'"]+)[\'"]\s*\)/',
            '/update_option\s*\(\s*[\'"]([^\'"]+)[\'"]\s*/',
            '/delete_option\s*\(\s*[\'"]([^\'"]+)[\'"]\s*\)/',
            '/get_transient\s*\(\s*[\'"]([^\'"]+)[\'"]\s*\)/',
            '/set_transient\s*\(\s*[\'"]([^\'"]+)[\'"]\s*/',
            '/get_user_meta\s*\([^,]+,\s*[\'"]([^\'"]+)[\'"]\s*/',
            '/get_post_meta\s*\([^,]+,\s*[\'"]([^\'"]+)[\'"]\s*/',
        ];

        foreach ($option_patterns as $pattern) {
            if (preg_match_all($pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
                foreach ($matches[1] as $match) {
                    $option_name = $match[0];
                    $line = $this->getLineNumber($content, $match[1]);
                    
                    // Track for cross-file analysis
                    $this->trackMagicString($file, $option_name, $line);
                    
                    // Check if this option appears multiple times
                    $occurrences = substr_count($content, "'{$option_name}'") + 
                                   substr_count($content, "\"{$option_name}\"");
                    
                    if ($occurrences > 1) {
                        $violations[] = new Violation(
                            rule: $this->getName(),
                            file: $file,
                            line: $line,
                            message: sprintf(
                                'Option key "%s" appears %d times — consider using a constant',
                                $option_name,
                                $occurrences
                            ),
                            severity: Severity::WARNING,
                            suggestion: sprintf(
                                'Define: const OPTION_%s = \'%s\';',
                                strtoupper(str_replace('-', '_', $option_name)),
                                $option_name
                            ),
                            code_snippet: $this->getCodeSnippet($content, $line)
                        );
                    }
                }
            }
        }

        // Detect duplicated capability strings
        $cap_pattern = '/(?:current_user_can|user_can)\s*\(\s*[\'"]([^\'"]+)[\'"]\s*\)/';
        $caps_found = [];
        
        if (preg_match_all($cap_pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
            foreach ($matches[1] as $match) {
                $cap = $match[0];
                if (!isset($caps_found[$cap])) {
                    $caps_found[$cap] = 0;
                }
                $caps_found[$cap]++;
            }

            foreach ($caps_found as $cap => $count) {
                if ($count > 2) {
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: 1, // General file warning
                        message: sprintf(
                            'Capability "%s" checked %d times — centralize permission logic',
                            $cap,
                            $count
                        ),
                        severity: Severity::INFO,
                        suggestion: 'Create a dedicated permission check method'
                    );
                }
            }
        }

        return $violations;
    }

    private function trackMagicString(string $file, string $value, int $line): void {
        $key = md5($value);
        if (!isset($this->magic_strings[$key])) {
            $this->magic_strings[$key] = [
                'value' => $value,
                'occurrences' => [],
            ];
        }
        $this->magic_strings[$key]['occurrences'][] = [
            'file' => $file,
            'line' => $line,
        ];
    }

    public function getCrossFileViolations(): array {
        $violations = [];
        
        foreach ($this->magic_strings as $data) {
            if (count($data['occurrences']) > 1) {
                $files = array_unique(array_column($data['occurrences'], 'file'));
                if (count($files) > 1) {
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $files[0],
                        line: $data['occurrences'][0]['line'],
                        message: sprintf(
                            'String "%s" duplicated across %d files',
                            $data['value'],
                            count($files)
                        ),
                        severity: Severity::WARNING,
                        suggestion: sprintf(
                            'Define in a central constants file. Found in: %s',
                            implode(', ', array_map('basename', $files))
                        )
                    );
                }
            }
        }

        return $violations;
    }
}

/**
 * Rule 4: Queries have boundaries
 * Detects unbounded database queries.
 */
class QueryBoundaryRule extends Rule {
    public function getName(): string {
        return 'query-boundaries';
    }

    public function getDescription(): string {
        return 'Queries have boundaries — Every database call has a LIMIT';
    }

    public function analyze(string $file, string $content, array $tokens): array {
        $violations = [];

        // WP_Query without posts_per_page
        $wp_query_pattern = '/new\s+WP_Query\s*\(\s*(\[[^\]]+\]|\$[a-zA-Z_]+)/s';
        if (preg_match_all($wp_query_pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
            foreach ($matches[0] as $index => $match) {
                $line = $this->getLineNumber($content, $match[1]);
                $args = $matches[1][$index][0];
                
                // Check if posts_per_page or numberposts is set
                if (strpos($args, '$') === 0) {
                    // Variable args - can't statically analyze, give info
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: $line,
                        message: 'WP_Query with variable args — ensure posts_per_page is set',
                        severity: Severity::INFO,
                        suggestion: 'Verify $args includes "posts_per_page" => N',
                        code_snippet: $this->getCodeSnippet($content, $line)
                    );
                } elseif (
                    stripos($args, 'posts_per_page') === false &&
                    stripos($args, 'numberposts') === false &&
                    stripos($args, 'nopaging') === false
                ) {
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: $line,
                        message: 'WP_Query without posts_per_page — will load ALL posts',
                        severity: Severity::ERROR,
                        suggestion: 'Add "posts_per_page" => 100 (or appropriate limit)',
                        code_snippet: $this->getCodeSnippet($content, $line)
                    );
                }
            }
        }

        // get_posts without numberposts
        $get_posts_pattern = '/get_posts\s*\(\s*(\[[^\]]+\])/s';
        if (preg_match_all($get_posts_pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
            foreach ($matches[0] as $index => $match) {
                $line = $this->getLineNumber($content, $match[1]);
                $args = $matches[1][$index][0];
                
                if (
                    stripos($args, 'numberposts') === false &&
                    stripos($args, 'posts_per_page') === false
                ) {
                    // get_posts defaults to 5, but explicit is better
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: $line,
                        message: 'get_posts without explicit limit — defaults to 5, but be explicit',
                        severity: Severity::INFO,
                        suggestion: 'Add "numberposts" => N for clarity',
                        code_snippet: $this->getCodeSnippet($content, $line)
                    );
                }
            }
        }

        // Direct SQL without LIMIT
        $sql_patterns = [
            '/\$wpdb->get_results\s*\(\s*["\']SELECT[^"\']+["\']\s*\)/is',
            '/\$wpdb->get_col\s*\(\s*["\']SELECT[^"\']+["\']\s*\)/is',
            '/\$wpdb->query\s*\(\s*["\']SELECT[^"\']+["\']\s*\)/is',
        ];

        foreach ($sql_patterns as $pattern) {
            if (preg_match_all($pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
                foreach ($matches[0] as $match) {
                    $sql = $match[0];
                    $line = $this->getLineNumber($content, $match[1]);
                    
                    if (stripos($sql, 'LIMIT') === false) {
                        $violations[] = new Violation(
                            rule: $this->getName(),
                            file: $file,
                            line: $line,
                            message: 'SQL SELECT without LIMIT clause',
                            severity: Severity::ERROR,
                            suggestion: 'Add LIMIT clause to prevent unbounded results',
                            code_snippet: $this->getCodeSnippet($content, $line)
                        );
                    }
                }
            }
        }

        // N+1 pattern detection: query in loop
        $this->detectNPlusOne($file, $content, $violations);

        return $violations;
    }

    private function detectNPlusOne(string $file, string $content, array &$violations): void {
        $lines = explode("\n", $content);
        $in_loop = false;
        $loop_start_line = 0;
        $brace_depth = 0;

        $loop_keywords = ['foreach', 'for', 'while'];
        $query_patterns = [
            'get_post_meta',
            'get_user_meta', 
            'get_term_meta',
            'get_option',
            'WP_Query',
            'get_posts',
            '$wpdb->get',
            '$wpdb->query',
        ];

        foreach ($lines as $line_num => $line_content) {
            $line_num++; // 1-indexed

            // Track loop entry
            foreach ($loop_keywords as $keyword) {
                if (preg_match('/\b' . $keyword . '\s*\(/', $line_content)) {
                    $in_loop = true;
                    $loop_start_line = $line_num;
                    $brace_depth = 0;
                }
            }

            // Track braces
            if ($in_loop) {
                $brace_depth += substr_count($line_content, '{');
                $brace_depth -= substr_count($line_content, '}');

                if ($brace_depth <= 0) {
                    $in_loop = false;
                }

                // Check for queries inside loop
                foreach ($query_patterns as $pattern) {
                    if (strpos($line_content, $pattern) !== false) {
                        $violations[] = new Violation(
                            rule: $this->getName(),
                            file: $file,
                            line: $line_num,
                            message: sprintf(
                                'Potential N+1 query: %s inside loop (started line %d)',
                                $pattern,
                                $loop_start_line
                            ),
                            severity: Severity::WARNING,
                            suggestion: 'Batch queries outside the loop, then look up in loop',
                            code_snippet: $this->getCodeSnippet($content, $line_num)
                        );
                    }
                }
            }
        }
    }
}

/**
 * Rule 5: Fail gracefully
 * Detects unhandled error conditions.
 */
class GracefulFailureRule extends Rule {
    public function getName(): string {
        return 'graceful-failure';
    }

    public function getDescription(): string {
        return 'Fail gracefully — Assume it will break';
    }

    public function analyze(string $file, string $content, array $tokens): array {
        $violations = [];

        // wp_remote_get/post without error checking
        $remote_patterns = [
            'wp_remote_get',
            'wp_remote_post',
            'wp_remote_request',
            'wp_safe_remote_get',
            'wp_safe_remote_post',
        ];

        foreach ($remote_patterns as $func) {
            $pattern = '/\$(\w+)\s*=\s*' . $func . '\s*\([^;]+;/';
            if (preg_match_all($pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
                foreach ($matches[0] as $index => $match) {
                    $var_name = $matches[1][$index][0];
                    $line = $this->getLineNumber($content, $match[1]);
                    
                    // Check if is_wp_error is called on this variable nearby
                    $search_area = substr($content, $match[1], 500);
                    if (strpos($search_area, "is_wp_error(\${$var_name})") === false &&
                        strpos($search_area, "is_wp_error( \${$var_name} )") === false) {
                        $violations[] = new Violation(
                            rule: $this->getName(),
                            file: $file,
                            line: $line,
                            message: sprintf('%s result not checked with is_wp_error()', $func),
                            severity: Severity::WARNING,
                            suggestion: sprintf('Add: if (is_wp_error($%s)) { /* handle error */ }', $var_name),
                            code_snippet: $this->getCodeSnippet($content, $line)
                        );
                    }
                }
            }
        }

        // file_get_contents without error handling
        if (preg_match_all('/\$(\w+)\s*=\s*file_get_contents\s*\([^;]+;/', $content, $matches, PREG_OFFSET_CAPTURE)) {
            foreach ($matches[0] as $index => $match) {
                $var_name = $matches[1][$index][0];
                $line = $this->getLineNumber($content, $match[1]);
                
                $search_area = substr($content, $match[1], 300);
                if (strpos($search_area, "=== false") === false &&
                    strpos($search_area, "!== false") === false &&
                    strpos($search_area, "if (\${$var_name})") === false) {
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: $line,
                        message: 'file_get_contents result not checked for false',
                        severity: Severity::WARNING,
                        suggestion: 'Add: if ($result === false) { /* handle error */ }',
                        code_snippet: $this->getCodeSnippet($content, $line)
                    );
                }
            }
        }

        // json_decode without error handling (PHP 7.3+)
        if (preg_match_all('/json_decode\s*\([^;]+;/', $content, $matches, PREG_OFFSET_CAPTURE)) {
            foreach ($matches[0] as $match) {
                $line = $this->getLineNumber($content, $match[1]);
                
                $search_area = substr($content, $match[1], 300);
                if (strpos($search_area, 'json_last_error') === false &&
                    strpos($search_area, 'JSON_THROW_ON_ERROR') === false) {
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: $line,
                        message: 'json_decode without error checking',
                        severity: Severity::INFO,
                        suggestion: 'Use JSON_THROW_ON_ERROR flag or check json_last_error()',
                        code_snippet: $this->getCodeSnippet($content, $line)
                    );
                }
            }
        }

        return $violations;
    }
}

/**
 * Rule 6: Ship clean
 * Detects debug code that shouldn't ship.
 */
class ShipCleanRule extends Rule {
    public function getName(): string {
        return 'ship-clean';
    }

    public function getDescription(): string {
        return 'Ship clean — Debug code is for debugging';
    }

    public function analyze(string $file, string $content, array $tokens): array {
        $violations = [];

        foreach ($this->config->debug_functions as $func) {
            $pattern = '/\b' . preg_quote($func, '/') . '\s*\(/';
            if (preg_match_all($pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
                foreach ($matches[0] as $match) {
                    $line = $this->getLineNumber($content, $match[1]);
                    
                    // Check if it's in a conditional debug block
                    $line_content = $this->getFullLine($content, $line);
                    $is_conditional = preg_match('/if\s*\(\s*(defined|WP_DEBUG|SCRIPT_DEBUG)/', $line_content) ||
                                      preg_match('/WP_DEBUG\s*&&/', $line_content);

                    if (!$is_conditional) {
                        $violations[] = new Violation(
                            rule: $this->getName(),
                            file: $file,
                            line: $line,
                            message: sprintf('Debug function %s() found in production code', $func),
                            severity: $func === 'error_log' ? Severity::WARNING : Severity::ERROR,
                            suggestion: 'Remove before shipping or wrap in WP_DEBUG conditional',
                            code_snippet: $this->getCodeSnippet($content, $line)
                        );
                    }
                }
            }
        }

        // TODO/FIXME/HACK comments
        $comment_patterns = [
            'TODO'  => Severity::INFO,
            'FIXME' => Severity::WARNING,
            'HACK'  => Severity::WARNING,
            'XXX'   => Severity::WARNING,
        ];

        foreach ($comment_patterns as $marker => $severity) {
            $pattern = '/\/\/.*\b' . $marker . '\b|\/\*.*\b' . $marker . '\b/i';
            if (preg_match_all($pattern, $content, $matches, PREG_OFFSET_CAPTURE)) {
                foreach ($matches[0] as $match) {
                    $line = $this->getLineNumber($content, $match[1]);
                    $violations[] = new Violation(
                        rule: $this->getName(),
                        file: $file,
                        line: $line,
                        message: sprintf('%s comment found — address before shipping', $marker),
                        severity: $severity,
                        suggestion: 'Resolve the issue or create a ticket to track it',
                        code_snippet: $this->getCodeSnippet($content, $line)
                    );
                }
            }
        }

        return $violations;
    }

    private function getFullLine(string $content, int $line): string {
        $lines = explode("\n", $content);
        return $lines[$line - 1] ?? '';
    }
}

/**
 * Main analyzer that orchestrates all rules.
 */
class Analyzer {
    private Config $config;
    private array $rules = [];
    private array $violations = [];

    public function __construct(string $project_root) {
        $this->config = Config::load($project_root);
        
        $this->rules = [
            new DuplicationRule($this->config),
            new StateGatesRule($this->config),
            new SingleTruthRule($this->config),
            new QueryBoundaryRule($this->config),
            new GracefulFailureRule($this->config),
            new ShipCleanRule($this->config),
        ];
    }

    public function analyze(string $path, ?string $rule_filter = null): array {
        $this->violations = [];
        
        // First pass: collect all functions for duplication detection
        $files = $this->getPhpFiles($path);
        
        // Analyze each file
        foreach ($files as $file) {
            $content = file_get_contents($file);
            $tokens = token_get_all($content);
            
            foreach ($this->rules as $rule) {
                if ($rule_filter && $rule->getName() !== $rule_filter) {
                    continue;
                }
                
                $file_violations = $rule->analyze($file, $content, $tokens);
                $this->violations = array_merge($this->violations, $file_violations);
            }
        }

        // Add cross-file violations
        foreach ($this->rules as $rule) {
            if ($rule instanceof SingleTruthRule) {
                $cross_file = $rule->getCrossFileViolations();
                $this->violations = array_merge($this->violations, $cross_file);
            }
        }

        return $this->violations;
    }

    private function getPhpFiles(string $path): array {
        $files = [];
        
        if (is_file($path) && pathinfo($path, PATHINFO_EXTENSION) === 'php') {
            return [$path];
        }

        $iterator = new \RecursiveIteratorIterator(
            new \RecursiveDirectoryIterator($path, \RecursiveDirectoryIterator::SKIP_DOTS)
        );

        foreach ($iterator as $file) {
            $filepath = $file->getPathname();
            
            // Skip ignored paths
            $skip = false;
            foreach ($this->config->ignore_paths as $ignore) {
                if (strpos($filepath, $ignore) !== false) {
                    $skip = true;
                    break;
                }
            }
            
            if (!$skip && $file->isFile() && $file->getExtension() === 'php') {
                $files[] = $filepath;
            }
        }

        return $files;
    }

    public function getViolations(): array {
        return $this->violations;
    }

    public function getRules(): array {
        return $this->rules;
    }
}

/**
 * Output formatters.
 */
class Formatter {
    public static function console(array $violations): string {
        if (empty($violations)) {
            return "\033[32m✓ No violations found\033[0m\n";
        }

        $output = [];
        $by_file = [];

        foreach ($violations as $v) {
            $by_file[$v->file][] = $v;
        }

        foreach ($by_file as $file => $file_violations) {
            $output[] = "\n\033[1m" . $file . "\033[0m";
            
            foreach ($file_violations as $v) {
                $color = match ($v->severity) {
                    Severity::ERROR   => "\033[31m",
                    Severity::WARNING => "\033[33m",
                    default           => "\033[36m",
                };
                
                $output[] = sprintf(
                    "  %s%s\033[0m Line %d: %s",
                    $color,
                    strtoupper($v->severity),
                    $v->line,
                    $v->message
                );
                
                if ($v->suggestion) {
                    $output[] = "    → " . $v->suggestion;
                }
            }
        }

        $counts = [
            Severity::ERROR   => 0,
            Severity::WARNING => 0,
            Severity::INFO    => 0,
        ];
        foreach ($violations as $v) {
            $counts[$v->severity]++;
        }

        $output[] = sprintf(
            "\n\033[1mSummary:\033[0m %d errors, %d warnings, %d info",
            $counts[Severity::ERROR],
            $counts[Severity::WARNING],
            $counts[Severity::INFO]
        );

        return implode("\n", $output) . "\n";
    }

    public static function json(array $violations): string {
        return json_encode(
            array_map(fn($v) => $v->toArray(), $violations),
            JSON_PRETTY_PRINT
        );
    }

    public static function github(array $violations): string {
        $output = [];
        
        foreach ($violations as $v) {
            $level = match ($v->severity) {
                Severity::ERROR   => 'error',
                Severity::WARNING => 'warning',
                default           => 'notice',
            };
            
            $output[] = sprintf(
                '::%s file=%s,line=%d,title=%s::%s',
                $level,
                $v->file,
                $v->line,
                $v->rule,
                $v->message
            );
        }

        return implode("\n", $output);
    }
}

// =============================================================================
// CLI ENTRY POINT
// =============================================================================

if (php_sapi_name() === 'cli' && realpath($argv[0]) === __FILE__) {
    $options = getopt('', [
        'rule:',
        'format:',
        'fail-on:',
        'help',
    ]);

    if (isset($options['help']) || $argc < 2) {
        echo <<<HELP
Golden Rules Analyzer v1.0.0

Usage: php golden-rules-analyzer.php <path> [options]

Options:
  --rule=<name>      Run only specific rule (duplication, state-gates, 
                     single-truth, query-boundaries, graceful-failure, ship-clean)
  --format=<type>    Output format: console (default), json, github
  --fail-on=<level>  Exit non-zero on: error, warning, info
  --help             Show this help

Examples:
  php golden-rules-analyzer.php /path/to/plugin
  php golden-rules-analyzer.php . --rule=query-boundaries --format=json
  php golden-rules-analyzer.php . --format=github --fail-on=error

HELP;
        exit(0);
    }

    $path = $argv[1];
    if (!file_exists($path)) {
        fwrite(STDERR, "Error: Path not found: {$path}\n");
        exit(1);
    }

    $analyzer = new Analyzer($path);
    $violations = $analyzer->analyze($path, $options['rule'] ?? null);

    $format = $options['format'] ?? 'console';
    $output = match ($format) {
        'json'   => Formatter::json($violations),
        'github' => Formatter::github($violations),
        default  => Formatter::console($violations),
    };

    echo $output;

    // Exit code based on fail-on threshold
    if (isset($options['fail-on'])) {
        $threshold = $options['fail-on'];
        $should_fail = false;
        
        foreach ($violations as $v) {
            if ($threshold === 'info') {
                $should_fail = true;
                break;
            }
            if ($threshold === 'warning' && in_array($v->severity, [Severity::ERROR, Severity::WARNING])) {
                $should_fail = true;
                break;
            }
            if ($threshold === 'error' && $v->severity === Severity::ERROR) {
                $should_fail = true;
                break;
            }
        }
        
        exit($should_fail ? 1 : 0);
    }

    exit(0);
}