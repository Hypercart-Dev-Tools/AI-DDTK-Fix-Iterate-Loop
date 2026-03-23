<?php
/**
 * Plugin Name: AI-DDTK Abilities
 * Description: Registers Phase 1 (content CRUD), Phase 2 (introspection), and Phase 3 (options write)
 *              abilities for the WordPress MCP Adapter. Part of AI-DDTK — see https://github.com/Hypercart-Dev-Tools/AI-DDTK
 *
 * Installation: Copy this file to wp-content/mu-plugins/ai-ddtk-abilities.php on any WordPress 6.9+
 *               site that has the MCP Adapter installed (wordpress/mcp-adapter via Composer).
 *
 * Requirements:
 *   - WordPress 6.9+ (Abilities API in core)
 *   - wordpress/mcp-adapter (Composer package)
 *
 * All abilities are exposed via the MCP Adapter default server and can be called by AI agents
 * without browser automation. Abilities require appropriate WordPress capabilities per call.
 *
 * @see https://github.com/WordPress/mcp-adapter
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

/**
 * Sanitize a single post meta value.
 *
 * Strings are sanitized with sanitize_text_field(). Integers/floats are cast to
 * their respective scalar types. Booleans are cast to bool. Arrays and objects are
 * returned as-is (WordPress serializes them via update_post_meta internally).
 *
 * @param mixed $value Raw meta value from agent input.
 * @return mixed Sanitized value.
 */
function _ai_ddtk_sanitize_meta_value( $value ) {
	if ( is_string( $value ) ) {
		return sanitize_text_field( $value );
	}
	if ( is_int( $value ) ) {
		return (int) $value;
	}
	if ( is_float( $value ) ) {
		return (float) $value;
	}
	if ( is_bool( $value ) ) {
		return (bool) $value;
	}
	// Arrays and objects: return as-is; WordPress handles serialization.
	return $value;
}

/**
 * Return the hardcoded options blocklist used by ai-ddtk/update-options.
 *
 * Keys are grouped into two tiers:
 *   - 'always_refuse'    : Never writable via this ability regardless of confirm_dangerous.
 *   - 'require_confirm'  : Writable only when the caller passes confirm_dangerous: true.
 *
 * Both lists are filterable via the 'ai_ddtk_options_blocklist' filter so that
 * site owners can extend them without patching this file.
 *
 * @return array{ always_refuse: string[], require_confirm: string[] }
 */
function _ai_ddtk_options_blocklist(): array {
	$defaults = [
		'always_refuse'   => [
			'active_plugins',           // Activation/deactivation must go through WP-CLI hooks.
			'active_sitewide_plugins',  // Multisite equivalent.
		],
		'require_confirm' => [
			'siteurl',                  // Relocates the entire site; flush rewrite rules after.
			'home',                     // Front-end URL; same risk as siteurl.
			'template',                 // Changes active parent theme directory.
			'stylesheet',               // Changes active theme (child or standalone).
			'admin_email',              // Sensitive account contact.
		],
	];

	/** @var array{ always_refuse: string[], require_confirm: string[] } $list */
	$list = apply_filters( 'ai_ddtk_options_blocklist', $defaults );
	return $list;
}

// ─────────────────────────────────────────────────────────────────────────────
// PHASE 1 — Content CRUD Abilities
// ─────────────────────────────────────────────────────────────────────────────

add_action( 'wp_abilities_api_init', function () {

	// ── ai-ddtk/create-post ──────────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/create-post', [
		'label'       => 'Create Post',
		'description' => 'Create a post, page, or custom post type entry with optional meta and taxonomy terms.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'post_type' => [
					'type'        => 'string',
					'description' => 'Post type slug (e.g. post, page, product). Defaults to post.',
					'default'     => 'post',
				],
				'title' => [
					'type'        => 'string',
					'description' => 'Post title (required).',
				],
				'content' => [
					'type'        => 'string',
					'description' => 'Post body content.',
				],
				'status' => [
					'type'        => 'string',
					'description' => 'Post status (draft, publish, pending, private). Defaults to draft.',
					'default'     => 'draft',
				],
				'meta' => [
					'type'        => 'object',
					'description' => 'Key/value pairs to set as post meta.',
				],
				'terms' => [
					'type'        => 'object',
					'description' => 'Taxonomy to term-slug/ID mapping, e.g. {"category": ["news", 5]}.',
				],
			],
			'required' => [ 'title' ],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success'  => [ 'type' => 'boolean' ],
				'id'       => [ 'type' => 'integer' ],
				'title'    => [ 'type' => 'string' ],
				'status'   => [ 'type' => 'string' ],
				'edit_url' => [ 'type' => 'string' ],
				'error'    => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function ( $params ) {
			if ( ! current_user_can( 'edit_posts' ) ) {
				return false;
			}
			$status = isset( $params['status'] ) ? $params['status'] : 'draft';
			if ( 'publish' === $status && ! current_user_can( 'publish_posts' ) ) {
				return false;
			}
			return true;
		},
		'execute_callback' => function ( $params ) {
			$post_type = isset( $params['post_type'] ) ? sanitize_key( $params['post_type'] ) : 'post';
			$title     = isset( $params['title'] )     ? sanitize_text_field( $params['title'] ) : '';
			$content   = isset( $params['content'] )   ? wp_kses_post( $params['content'] ) : '';
			$status    = isset( $params['status'] )    ? sanitize_key( $params['status'] ) : 'draft';

			if ( $title === '' ) {
				return [ 'success' => false, 'error' => 'title is required and must not be empty.' ];
			}

			if ( ! in_array( $status, [ 'draft', 'publish', 'pending', 'private', 'future' ], true ) ) {
				return [ 'success' => false, 'error' => 'Invalid status value.' ];
			}

			$post_id = wp_insert_post( [
				'post_type'    => $post_type,
				'post_title'   => $title,
				'post_content' => $content,
				'post_status'  => $status,
			], true );

			if ( is_wp_error( $post_id ) ) {
				return [ 'success' => false, 'error' => $post_id->get_error_message() ];
			}

			// Post meta.
			if ( ! empty( $params['meta'] ) && is_array( $params['meta'] ) ) {
				foreach ( $params['meta'] as $meta_key => $meta_value ) {
					$sanitized_key = sanitize_key( $meta_key );
					if ( $sanitized_key ) {
						update_post_meta( $post_id, $sanitized_key, _ai_ddtk_sanitize_meta_value( $meta_value ) );
				}
				}
			}

			// Taxonomy terms.
			if ( ! empty( $params['terms'] ) && is_array( $params['terms'] ) ) {
				foreach ( $params['terms'] as $taxonomy => $terms ) {
					$taxonomy = sanitize_key( $taxonomy );
					if ( taxonomy_exists( $taxonomy ) && is_array( $terms ) ) {
						$term_ids = [];
						foreach ( $terms as $t ) {
							if ( is_numeric( $t ) ) {
								$term_ids[] = absint( $t );
							} else {
								$term_obj = get_term_by( 'slug', sanitize_text_field( $t ), $taxonomy );
								if ( $term_obj ) {
									$term_ids[] = $term_obj->term_id;
								}
							}
						}
						wp_set_post_terms( $post_id, $term_ids, $taxonomy );
					}
				}
			}

			return [
				'success'  => true,
				'id'       => $post_id,
				'title'    => get_the_title( $post_id ),
				'status'   => get_post_status( $post_id ),
				'edit_url' => get_edit_post_link( $post_id, 'raw' ),
			];
		},
	] );

	// ── ai-ddtk/update-post ──────────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/update-post', [
		'label'       => 'Update Post',
		'description' => 'Update title, content, status, meta, or taxonomy terms on an existing post/page/CPT.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'id' => [
					'type'        => 'integer',
					'description' => 'Post ID to update (required).',
				],
				'title' => [
					'type'        => 'string',
					'description' => 'New post title.',
				],
				'content' => [
					'type'        => 'string',
					'description' => 'New post content.',
				],
				'status' => [
					'type'        => 'string',
					'description' => 'New post status.',
				],
				'meta' => [
					'type'        => 'object',
					'description' => 'Meta key/value pairs to update.',
				],
				'terms' => [
					'type'        => 'object',
					'description' => 'Taxonomy to term-slug/ID mapping.',
				],
			],
			'required' => [ 'id' ],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success'        => [ 'type' => 'boolean' ],
				'id'             => [ 'type' => 'integer' ],
				'title'          => [ 'type' => 'string' ],
				'status'         => [ 'type' => 'string' ],
				'updated_fields' => [ 'type' => 'array', 'items' => [ 'type' => 'string' ] ],
				'error'          => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function ( $params ) {
			$id = isset( $params['id'] ) ? absint( $params['id'] ) : 0;
			return $id > 0 && current_user_can( 'edit_post', $id );
		},
		'execute_callback' => function ( $params ) {
			$id = isset( $params['id'] ) ? absint( $params['id'] ) : 0;

			if ( ! $id || ! get_post( $id ) ) {
				return [ 'success' => false, 'error' => 'Post not found.' ];
			}

			$post_data      = [ 'ID' => $id ];
			$updated_fields = [];

			if ( isset( $params['title'] ) ) {
				$post_data['post_title'] = sanitize_text_field( $params['title'] );
				$updated_fields[]        = 'title';
			}
			if ( isset( $params['content'] ) ) {
				$post_data['post_content'] = wp_kses_post( $params['content'] );
				$updated_fields[]          = 'content';
			}
			if ( isset( $params['status'] ) ) {
				$status = sanitize_key( $params['status'] );
				if ( ! in_array( $status, [ 'draft', 'publish', 'pending', 'private', 'future', 'trash' ], true ) ) {
					return [ 'success' => false, 'error' => 'Invalid status value.' ];
				}
				$post_data['post_status'] = $status;
				$updated_fields[]         = 'status';
			}

			if ( count( $post_data ) > 1 ) {
				$result = wp_update_post( $post_data, true );
				if ( is_wp_error( $result ) ) {
					return [ 'success' => false, 'error' => $result->get_error_message() ];
				}
			}

			// Post meta.
			if ( ! empty( $params['meta'] ) && is_array( $params['meta'] ) ) {
				foreach ( $params['meta'] as $meta_key => $meta_value ) {
					$sanitized_key = sanitize_key( $meta_key );
					if ( $sanitized_key ) {
						update_post_meta( $id, $sanitized_key, _ai_ddtk_sanitize_meta_value( $meta_value ) );
					}
				}
				$updated_fields[] = 'meta';
			}

			// Taxonomy terms.
			if ( ! empty( $params['terms'] ) && is_array( $params['terms'] ) ) {
				foreach ( $params['terms'] as $taxonomy => $terms ) {
					$taxonomy = sanitize_key( $taxonomy );
					if ( taxonomy_exists( $taxonomy ) && is_array( $terms ) ) {
						$term_ids = [];
						foreach ( $terms as $t ) {
							if ( is_numeric( $t ) ) {
								$term_ids[] = absint( $t );
							} else {
								$term_obj = get_term_by( 'slug', sanitize_text_field( $t ), $taxonomy );
								if ( $term_obj ) {
									$term_ids[] = $term_obj->term_id;
								}
							}
						}
						wp_set_post_terms( $id, $term_ids, $taxonomy );
					}
				}
				$updated_fields[] = 'terms';
			}

			return [
				'success'        => true,
				'id'             => $id,
				'title'          => get_the_title( $id ),
				'status'         => get_post_status( $id ),
				'updated_fields' => $updated_fields,
			];
		},
	] );

	// ── ai-ddtk/list-posts ───────────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/list-posts', [
		'label'       => 'List Posts',
		'description' => 'List posts/pages/CPTs with optional filters by type, status, taxonomy, or date range.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'post_type'   => [ 'type' => 'string',  'description' => 'Post type slug. Defaults to post.',  'default' => 'post' ],
				'status'      => [ 'type' => 'string',  'description' => 'Post status filter. Defaults to any.', 'default' => 'any' ],
				'taxonomy'    => [ 'type' => 'string',  'description' => 'Taxonomy slug for term filter.' ],
				'term'        => [ 'type' => 'string',  'description' => 'Term slug or ID to filter by (requires taxonomy).' ],
				'date_after'  => [ 'type' => 'string',  'description' => 'ISO 8601 date — return posts published after this date.' ],
				'date_before' => [ 'type' => 'string',  'description' => 'ISO 8601 date — return posts published before this date.' ],
				'per_page'    => [ 'type' => 'integer', 'description' => 'Posts per page (1–100). Defaults to 20.', 'default' => 20 ],
				'page'        => [ 'type' => 'integer', 'description' => 'Page number. Defaults to 1.', 'default' => 1 ],
			],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success' => [ 'type' => 'boolean' ],
				'posts'   => [
					'type'  => 'array',
					'items' => [
						'type'       => 'object',
						'properties' => [
							'id'        => [ 'type' => 'integer' ],
							'title'     => [ 'type' => 'string' ],
							'status'    => [ 'type' => 'string' ],
							'post_type' => [ 'type' => 'string' ],
							'date'      => [ 'type' => 'string' ],
							'link'      => [ 'type' => 'string' ],
						],
					],
				],
				'total' => [ 'type' => 'integer' ],
				'pages' => [ 'type' => 'integer' ],
				'error' => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'read' );
		},
		'execute_callback' => function ( $params ) {
			$post_type = isset( $params['post_type'] ) ? sanitize_key( $params['post_type'] ) : 'post';
			$status    = isset( $params['status'] )    ? sanitize_key( $params['status'] ) : 'any';
			$per_page  = isset( $params['per_page'] )  ? min( absint( $params['per_page'] ), 100 ) : 20;
			$page      = isset( $params['page'] )      ? max( absint( $params['page'] ), 1 ) : 1;

			if ( $per_page < 1 ) {
				$per_page = 20;
			}

			$query_args = [
				'post_type'      => $post_type,
				'post_status'    => $status,
				'posts_per_page' => $per_page,
				'paged'          => $page,
				'no_found_rows'  => false,
			];

			// Taxonomy filter.
			if ( ! empty( $params['taxonomy'] ) && ! empty( $params['term'] ) ) {
				$taxonomy = sanitize_key( $params['taxonomy'] );
				$term_val = sanitize_text_field( $params['term'] );
				if ( taxonomy_exists( $taxonomy ) ) {
					$query_args['tax_query'] = [ // phpcs:ignore WordPress.DB.SlowDBQuery
						[
							'taxonomy' => $taxonomy,
							'field'    => is_numeric( $term_val ) ? 'term_id' : 'slug',
							'terms'    => is_numeric( $term_val ) ? absint( $term_val ) : $term_val,
						],
					];
				}
			}

			// Date range filters.
			$date_query = [];
			if ( ! empty( $params['date_after'] ) ) {
				$date_query['after'] = sanitize_text_field( $params['date_after'] );
			}
			if ( ! empty( $params['date_before'] ) ) {
				$date_query['before'] = sanitize_text_field( $params['date_before'] );
			}
			if ( ! empty( $date_query ) ) {
				$date_query['inclusive'] = true;
				$query_args['date_query'] = [ $date_query ];
			}

			$query = new WP_Query( $query_args );
			$posts = [];

			foreach ( $query->posts as $post ) {
				$posts[] = [
					'id'        => $post->ID,
					'title'     => get_the_title( $post ),
					'status'    => $post->post_status,
					'post_type' => $post->post_type,
					'date'      => $post->post_date,
					'link'      => get_permalink( $post->ID ),
				];
			}

			return [
				'success' => true,
				'posts'   => $posts,
				'total'   => (int) $query->found_posts,
				'pages'   => (int) $query->max_num_pages,
			];
		},
	] );

	// ── ai-ddtk/delete-post ──────────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/delete-post', [
		'label'       => 'Trash Post',
		'description' => 'Move a post to the trash (never permanently deletes). Use wp-admin to permanently delete if needed.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'id' => [
					'type'        => 'integer',
					'description' => 'Post ID to trash (required).',
				],
			],
			'required' => [ 'id' ],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success' => [ 'type' => 'boolean' ],
				'id'      => [ 'type' => 'integer' ],
				'trashed' => [ 'type' => 'boolean' ],
				'error'   => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function ( $params ) {
			$id = isset( $params['id'] ) ? absint( $params['id'] ) : 0;
			return $id > 0 && current_user_can( 'delete_post', $id );
		},
		'execute_callback' => function ( $params ) {
			$id = isset( $params['id'] ) ? absint( $params['id'] ) : 0;

			if ( ! $id || ! get_post( $id ) ) {
				return [ 'success' => false, 'error' => 'Post not found.' ];
			}

			$result = wp_trash_post( $id );

			if ( ! $result ) {
				return [ 'success' => false, 'error' => 'Could not trash post. It may already be trashed.' ];
			}

			return [ 'success' => true, 'id' => $id, 'trashed' => true ];
		},
	] );

	// ── ai-ddtk/manage-taxonomy ──────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/manage-taxonomy', [
		'label'       => 'Manage Taxonomy',
		'description' => 'Create terms, assign terms to posts, or list terms for a taxonomy.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'action'   => [
					'type'        => 'string',
					'description' => 'Action to perform: create-term, assign-terms, or list-terms.',
					'enum'        => [ 'create-term', 'assign-terms', 'list-terms' ],
				],
				'taxonomy' => [
					'type'        => 'string',
					'description' => 'Taxonomy slug (e.g. category, post_tag).',
				],
				// create-term fields
				'name'   => [ 'type' => 'string',  'description' => '[create-term] Term name.' ],
				'slug'   => [ 'type' => 'string',  'description' => '[create-term] Term slug (optional).' ],
				'parent' => [ 'type' => 'integer', 'description' => '[create-term] Parent term ID (optional).' ],
				// assign-terms fields
				'post_id' => [ 'type' => 'integer', 'description' => '[assign-terms] Post ID to assign terms to.' ],
				'terms'   => [
					'type'        => 'array',
					'description' => '[assign-terms] Array of term IDs or slugs.',
					'items'       => [ 'type' => [ 'string', 'integer' ] ],
				],
				'append' => [ 'type' => 'boolean', 'description' => '[assign-terms] Append to existing terms (default true).' ],
				// list-terms fields
				'hide_empty' => [ 'type' => 'boolean', 'description' => '[list-terms] Exclude empty terms (default false).' ],
				'per_page'   => [ 'type' => 'integer', 'description' => '[list-terms] Number of terms to return (default 50).' ],
			],
			'required' => [ 'action', 'taxonomy' ],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success' => [ 'type' => 'boolean' ],
				'error'   => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function ( $params ) {
			$action = isset( $params['action'] ) ? $params['action'] : '';
			if ( 'create-term' === $action ) {
				return current_user_can( 'manage_categories' );
			}
			return current_user_can( 'edit_posts' );
		},
		'execute_callback' => function ( $params ) {
			$action   = isset( $params['action'] )   ? sanitize_text_field( $params['action'] ) : '';
			$taxonomy = isset( $params['taxonomy'] ) ? sanitize_key( $params['taxonomy'] ) : '';

			if ( ! taxonomy_exists( $taxonomy ) ) {
				return [ 'success' => false, 'error' => "Taxonomy '{$taxonomy}' does not exist." ];
			}

			if ( 'create-term' === $action ) {
				$name = isset( $params['name'] ) ? sanitize_text_field( $params['name'] ) : '';
				if ( $name === '' ) {
					return [ 'success' => false, 'error' => 'name is required for create-term.' ];
				}
				$args = [];
				if ( ! empty( $params['slug'] ) ) {
					$args['slug'] = sanitize_title( $params['slug'] );
				}
				if ( ! empty( $params['parent'] ) ) {
					$args['parent'] = absint( $params['parent'] );
				}
				$result = wp_insert_term( $name, $taxonomy, $args );
				if ( is_wp_error( $result ) ) {
					return [ 'success' => false, 'error' => $result->get_error_message() ];
				}
				return [
					'success'  => true,
					'term_id'  => $result['term_id'],
					'name'     => $name,
					'taxonomy' => $taxonomy,
				];
			}

			if ( 'assign-terms' === $action ) {
				$post_id = isset( $params['post_id'] ) ? absint( $params['post_id'] ) : 0;
				if ( ! $post_id || ! get_post( $post_id ) ) {
					return [ 'success' => false, 'error' => 'post_id is required and must refer to an existing post.' ];
				}
				$terms  = isset( $params['terms'] ) && is_array( $params['terms'] ) ? $params['terms'] : [];
				$append = isset( $params['append'] ) ? (bool) $params['append'] : true;

				$term_ids = [];
				foreach ( $terms as $t ) {
					if ( is_numeric( $t ) ) {
						$term_ids[] = absint( $t );
					} else {
						$term_obj = get_term_by( 'slug', sanitize_text_field( $t ), $taxonomy );
						if ( $term_obj ) {
							$term_ids[] = $term_obj->term_id;
						}
					}
				}

				$result = wp_set_post_terms( $post_id, $term_ids, $taxonomy, $append );
				if ( is_wp_error( $result ) ) {
					return [ 'success' => false, 'error' => $result->get_error_message() ];
				}
				return [ 'success' => true, 'post_id' => $post_id, 'taxonomy' => $taxonomy, 'assigned_term_ids' => $result ];
			}

			if ( 'list-terms' === $action ) {
				$hide_empty = isset( $params['hide_empty'] ) ? (bool) $params['hide_empty'] : false;
				$per_page   = isset( $params['per_page'] )   ? min( absint( $params['per_page'] ), 200 ) : 50;

				$terms = get_terms( [
					'taxonomy'   => $taxonomy,
					'hide_empty' => $hide_empty,
					'number'     => $per_page,
				] );

				if ( is_wp_error( $terms ) ) {
					return [ 'success' => false, 'error' => $terms->get_error_message() ];
				}

				$term_list = [];
				foreach ( $terms as $term ) {
					$term_list[] = [
						'term_id'  => $term->term_id,
						'name'     => $term->name,
						'slug'     => $term->slug,
						'count'    => $term->count,
						'parent'   => $term->parent,
					];
				}
				return [ 'success' => true, 'taxonomy' => $taxonomy, 'terms' => $term_list, 'count' => count( $term_list ) ];
			}

			return [ 'success' => false, 'error' => "Unknown action '{$action}'. Use: create-term, assign-terms, list-terms." ];
		},
	] );

	// ── ai-ddtk/batch-create-posts ───────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/batch-create-posts', [
		'label'       => 'Batch Create Posts',
		'description' => 'Create multiple posts in one call. Returns per-item results. Capped at 100 items.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'posts' => [
					'type'        => 'array',
					'description' => 'Array of post objects (same fields as create-post). Required.',
					'items'       => [ 'type' => 'object' ],
				],
				'post_type' => [
					'type'        => 'string',
					'description' => 'Default post type applied to all items that do not specify their own. Defaults to post.',
					'default'     => 'post',
				],
			],
			'required' => [ 'posts' ],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success' => [ 'type' => 'boolean' ],
				'created' => [ 'type' => 'integer' ],
				'failed'  => [ 'type' => 'integer' ],
				'results' => [
					'type'  => 'array',
					'items' => [
						'type'       => 'object',
						'properties' => [
							'index'  => [ 'type' => 'integer' ],
							'id'     => [ 'type' => 'integer' ],
							'title'  => [ 'type' => 'string' ],
							'status' => [ 'type' => 'string' ],
							'error'  => [ 'type' => 'string' ],
						],
					],
				],
				'error' => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'edit_posts' );
		},
		'execute_callback' => function ( $params ) {
			$posts_input = isset( $params['posts'] ) && is_array( $params['posts'] ) ? $params['posts'] : null;

			if ( null === $posts_input ) {
				return [ 'success' => false, 'error' => 'posts array is required.' ];
			}

			if ( count( $posts_input ) > 100 ) {
				return [ 'success' => false, 'error' => 'Batch size exceeds the maximum of 100 items.' ];
			}

			$default_type = isset( $params['post_type'] ) ? sanitize_key( $params['post_type'] ) : 'post';
			$created      = 0;
			$failed       = 0;
			$results      = [];

			foreach ( $posts_input as $index => $item ) {
				if ( ! is_array( $item ) ) {
					$failed++;
					$results[] = [ 'index' => $index, 'title' => '', 'status' => 'failed', 'error' => 'Item is not an object.' ];
					continue;
				}

				$post_type = isset( $item['post_type'] ) ? sanitize_key( $item['post_type'] ) : $default_type;
				$title     = isset( $item['title'] )     ? sanitize_text_field( $item['title'] ) : '';
				$content   = isset( $item['content'] )   ? wp_kses_post( $item['content'] ) : '';
				$status    = isset( $item['status'] )    ? sanitize_key( $item['status'] ) : 'draft';

				if ( $title === '' ) {
					$failed++;
					$results[] = [ 'index' => $index, 'title' => '', 'status' => 'failed', 'error' => 'title is required.' ];
					continue;
				}

				// Extra permission check: publishing requires publish_posts.
				if ( 'publish' === $status && ! current_user_can( 'publish_posts' ) ) {
					$status = 'draft';
				}

				$post_id = wp_insert_post( [
					'post_type'    => $post_type,
					'post_title'   => $title,
					'post_content' => $content,
					'post_status'  => $status,
				], true );

				if ( is_wp_error( $post_id ) ) {
					$failed++;
					$results[] = [ 'index' => $index, 'title' => $title, 'status' => 'failed', 'error' => $post_id->get_error_message() ];
					continue;
				}

				// Post meta.
				if ( ! empty( $item['meta'] ) && is_array( $item['meta'] ) ) {
					foreach ( $item['meta'] as $meta_key => $meta_value ) {
						$sanitized_key = sanitize_key( $meta_key );
						if ( $sanitized_key ) {
							update_post_meta( $post_id, $sanitized_key, _ai_ddtk_sanitize_meta_value( $meta_value ) );
						}
					}
				}

				$created++;
				$results[] = [
					'index'  => $index,
					'id'     => $post_id,
					'title'  => $title,
					'status' => get_post_status( $post_id ),
				];
			}

			return [
				'success' => true,
				'created' => $created,
				'failed'  => $failed,
				'results' => $results,
			];
		},
	] );

	// ── ai-ddtk/batch-update-posts ───────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/batch-update-posts', [
		'label'       => 'Batch Update Posts',
		'description' => 'Update multiple existing posts in one call. Each item must include an id. Capped at 100 items.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'updates' => [
					'type'        => 'array',
					'description' => 'Array of update objects. Each must include id (same fields as update-post). Required.',
					'items'       => [ 'type' => 'object' ],
				],
			],
			'required' => [ 'updates' ],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success' => [ 'type' => 'boolean' ],
				'updated' => [ 'type' => 'integer' ],
				'failed'  => [ 'type' => 'integer' ],
				'results' => [
					'type'  => 'array',
					'items' => [
						'type'       => 'object',
						'properties' => [
							'id'             => [ 'type' => 'integer' ],
							'status'         => [ 'type' => 'string' ],
							'updated_fields' => [ 'type' => 'array', 'items' => [ 'type' => 'string' ] ],
							'error'          => [ 'type' => 'string' ],
						],
					],
				],
				'error' => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'edit_posts' );
		},
		'execute_callback' => function ( $params ) {
			$updates_input = isset( $params['updates'] ) && is_array( $params['updates'] ) ? $params['updates'] : null;

			if ( null === $updates_input ) {
				return [ 'success' => false, 'error' => 'updates array is required.' ];
			}

			if ( count( $updates_input ) > 100 ) {
				return [ 'success' => false, 'error' => 'Batch size exceeds the maximum of 100 items.' ];
			}

			$updated = 0;
			$failed  = 0;
			$results = [];

			foreach ( $updates_input as $item ) {
				if ( ! is_array( $item ) ) {
					$failed++;
					$results[] = [ 'id' => 0, 'status' => 'failed', 'error' => 'Item is not an object.' ];
					continue;
				}

				$id = isset( $item['id'] ) ? absint( $item['id'] ) : 0;

				if ( ! $id ) {
					$failed++;
					$results[] = [ 'id' => 0, 'status' => 'failed', 'error' => 'id is required.' ];
					continue;
				}

				if ( ! get_post( $id ) ) {
					$failed++;
					$results[] = [ 'id' => $id, 'status' => 'failed', 'error' => 'Post not found.' ];
					continue;
				}

				if ( ! current_user_can( 'edit_post', $id ) ) {
					$failed++;
					$results[] = [ 'id' => $id, 'status' => 'failed', 'error' => 'Permission denied.' ];
					continue;
				}

				$post_data      = [ 'ID' => $id ];
				$updated_fields = [];

				if ( isset( $item['title'] ) ) {
					$post_data['post_title'] = sanitize_text_field( $item['title'] );
					$updated_fields[]        = 'title';
				}
				if ( isset( $item['content'] ) ) {
					$post_data['post_content'] = wp_kses_post( $item['content'] );
					$updated_fields[]          = 'content';
				}
				if ( isset( $item['status'] ) ) {
					$s = sanitize_key( $item['status'] );
					if ( in_array( $s, [ 'draft', 'publish', 'pending', 'private', 'future', 'trash' ], true ) ) {
						$post_data['post_status'] = $s;
						$updated_fields[]         = 'status';
					}
				}

				if ( count( $post_data ) > 1 ) {
					$result = wp_update_post( $post_data, true );
					if ( is_wp_error( $result ) ) {
						$failed++;
						$results[] = [ 'id' => $id, 'status' => 'failed', 'error' => $result->get_error_message() ];
						continue;
					}
				}

				// Post meta.
				if ( ! empty( $item['meta'] ) && is_array( $item['meta'] ) ) {
					foreach ( $item['meta'] as $meta_key => $meta_value ) {
						$sanitized_key = sanitize_key( $meta_key );
						if ( $sanitized_key ) {
							update_post_meta( $id, $sanitized_key, _ai_ddtk_sanitize_meta_value( $meta_value ) );
						}
					}
					$updated_fields[] = 'meta';
				}

				$updated++;
				$results[] = [
					'id'             => $id,
					'status'         => get_post_status( $id ),
					'updated_fields' => $updated_fields,
				];
			}

			return [
				'success' => true,
				'updated' => $updated,
				'failed'  => $failed,
				'results' => $results,
			];
		},
	] );

	// ─────────────────────────────────────────────────────────────────────────
	// PHASE 2 — Introspection Abilities
	// ─────────────────────────────────────────────────────────────────────────

	// ── ai-ddtk/get-options ──────────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/get-options', [
		'label'       => 'Get Options',
		'description' => 'Read WordPress options by exact key array or prefix match.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'keys' => [
					'type'        => 'array',
					'description' => 'Array of exact option names to retrieve.',
					'items'       => [ 'type' => 'string' ],
				],
				'prefix' => [
					'type'        => 'string',
					'description' => 'Return all options whose names begin with this prefix.',
				],
				'include_autoload' => [
					'type'        => 'boolean',
					'description' => 'Include autoload options when using prefix (default true).',
					'default'     => true,
				],
			],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success' => [ 'type' => 'boolean' ],
				'options' => [ 'type' => 'object' ],
				'count'   => [ 'type' => 'integer' ],
				'error'   => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'manage_options' );
		},
		'execute_callback' => function ( $params ) {
			global $wpdb;

			$options = [];

			// Exact key lookup.
			if ( ! empty( $params['keys'] ) && is_array( $params['keys'] ) ) {
				foreach ( $params['keys'] as $key ) {
					$key             = sanitize_text_field( $key );
					$options[ $key ] = get_option( $key );
				}
			}

			// Prefix query.
			if ( ! empty( $params['prefix'] ) ) {
				$prefix           = sanitize_text_field( $params['prefix'] );
				$include_autoload = isset( $params['include_autoload'] ) ? (bool) $params['include_autoload'] : true;
				$like             = $wpdb->esc_like( $prefix ) . '%';

				$where   = $include_autoload ? '' : " AND autoload = 'yes'";
				// phpcs:ignore WordPress.DB.DirectDatabaseQuery,WordPress.DB.PreparedSQL.InterpolatedNotPrepared
				$results = $wpdb->get_results(
					$wpdb->prepare( "SELECT option_name, option_value FROM {$wpdb->options} WHERE option_name LIKE %s" . $where, $like ),
					ARRAY_A
				);

				if ( $results ) {
					foreach ( $results as $row ) {
						$key             = $row['option_name'];
						$options[ $key ] = maybe_unserialize( $row['option_value'] );
					}
				}
			}

			if ( empty( $params['keys'] ) && empty( $params['prefix'] ) ) {
				return [ 'success' => false, 'error' => 'Provide at least one of: keys (array) or prefix (string).' ];
			}

			return [
				'success' => true,
				'options' => $options,
				'count'   => count( $options ),
			];
		},
	] );

	// ── ai-ddtk/list-post-types ──────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/list-post-types', [
		'label'       => 'List Post Types',
		'description' => 'Return all registered post types with labels, supports, and capabilities.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'public_only' => [
					'type'        => 'boolean',
					'description' => 'Return only publicly queryable post types (default false).',
					'default'     => false,
				],
			],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success'    => [ 'type' => 'boolean' ],
				'post_types' => [ 'type' => 'array' ],
				'count'      => [ 'type' => 'integer' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'read' );
		},
		'execute_callback' => function ( $params ) {
			$public_only = isset( $params['public_only'] ) ? (bool) $params['public_only'] : false;
			$query_args  = $public_only ? [ 'public' => true ] : [];

			$post_types = get_post_types( $query_args, 'objects' );
			$result     = [];

			foreach ( $post_types as $pt ) {
				$supports = [];
				foreach ( [ 'title', 'editor', 'author', 'thumbnail', 'excerpt', 'comments', 'revisions', 'custom-fields', 'page-attributes', 'post-formats' ] as $feature ) {
					if ( post_type_supports( $pt->name, $feature ) ) {
						$supports[] = $feature;
					}
				}

				$caps = (array) $pt->cap;

				$result[] = [
					'name'           => $pt->name,
					'label'          => $pt->label,
					'singular_label' => $pt->labels->singular_name,
					'public'         => (bool) $pt->public,
					'has_archive'    => (bool) $pt->has_archive,
					'supports'       => $supports,
					'capabilities'   => $caps,
				];
			}

			return [
				'success'    => true,
				'post_types' => $result,
				'count'      => count( $result ),
			];
		},
	] );

	// ── ai-ddtk/list-registered-blocks ──────────────────────────────────────
	wp_register_ability( 'ai-ddtk/list-registered-blocks', [
		'label'       => 'List Registered Blocks',
		'description' => 'Return all registered Gutenberg blocks, optionally filtered by namespace.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'namespace' => [
					'type'        => 'string',
					'description' => 'Filter by block namespace (e.g. core, my-plugin). Optional.',
				],
			],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success' => [ 'type' => 'boolean' ],
				'blocks'  => [
					'type'  => 'array',
					'items' => [
						'type'       => 'object',
						'properties' => [
							'name'       => [ 'type' => 'string' ],
							'title'      => [ 'type' => 'string' ],
							'category'   => [ 'type' => 'string' ],
							'is_dynamic' => [ 'type' => 'boolean' ],
						],
					],
				],
				'count' => [ 'type' => 'integer' ],
				'error' => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'read' );
		},
		'execute_callback' => function ( $params ) {
			if ( ! class_exists( 'WP_Block_Type_Registry' ) ) {
				return [ 'success' => false, 'error' => 'WP_Block_Type_Registry is not available. Requires WordPress 5.0+.' ];
			}

			$namespace_filter = isset( $params['namespace'] ) ? sanitize_text_field( $params['namespace'] ) : '';
			$registry         = WP_Block_Type_Registry::get_instance();
			$all_blocks       = $registry->get_all_registered();
			$blocks           = [];

			foreach ( $all_blocks as $name => $block ) {
				if ( $namespace_filter && strpos( $name, $namespace_filter . '/' ) !== 0 ) {
					continue;
				}
				$blocks[] = [
					'name'       => $name,
					'title'      => isset( $block->title ) ? $block->title : '',
					'category'   => isset( $block->category ) ? $block->category : '',
					'is_dynamic' => is_callable( $block->render_callback ),
				];
			}

			return [
				'success' => true,
				'blocks'  => $blocks,
				'count'   => count( $blocks ),
			];
		},
	] );

	// ── ai-ddtk/get-active-theme ─────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/get-active-theme', [
		'label'       => 'Get Active Theme',
		'description' => 'Return active theme information. Full details require switch_themes capability; gracefully degrades to name+version for read-only users.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		// No input_schema: ability takes no parameters. Omitting it avoids a WP core
		// validator bug where ExecuteAbilityAbility converts {} (decoded as []) to null
		// via empty(), then rest_validate_value_from_schema(null, type:object) fails.
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success'        => [ 'type' => 'boolean' ],
				'name'           => [ 'type' => 'string' ],
				'version'        => [ 'type' => 'string' ],
				'template'       => [ 'type' => 'string' ],
				'stylesheet'     => [ 'type' => 'string' ],
				'author'         => [ 'type' => 'string' ],
				'theme_uri'      => [ 'type' => 'string' ],
				'is_child_theme' => [ 'type' => 'boolean' ],
				'parent_theme'   => [ 'type' => [ 'string', 'null' ] ],
				'error'          => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'read' );
		},
		'execute_callback' => function () {
			$theme = wp_get_theme();

			if ( ! $theme->exists() ) {
				return [ 'success' => false, 'error' => 'Active theme not found.' ];
			}

			$response = [
				'success' => true,
				'name'    => $theme->get( 'Name' ),
				'version' => $theme->get( 'Version' ),
			];

			// Full details only if the user has switch_themes capability.
			if ( current_user_can( 'switch_themes' ) ) {
				$is_child    = $theme->get_template() !== $theme->get_stylesheet();
				$parent_name = null;
				if ( $is_child ) {
					$parent      = wp_get_theme( $theme->get_template() );
					$parent_name = $parent->exists() ? $parent->get( 'Name' ) : $theme->get_template();
				}

				$response['template']       = $theme->get_template();
				$response['stylesheet']     = $theme->get_stylesheet();
				$response['author']         = $theme->get( 'Author' );
				$response['theme_uri']      = $theme->get( 'ThemeURI' );
				$response['is_child_theme'] = $is_child;
				$response['parent_theme']   = $parent_name;
			}

			return $response;
		},
	] );

	// ── ai-ddtk/list-plugins ─────────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/list-plugins', [
		'label'       => 'List Plugins',
		'description' => 'Return active and/or inactive plugins with name, version, author, and status.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'properties' => [
				'status' => [
					'type'        => 'string',
					'description' => 'Filter by plugin status: active, inactive, or all. Defaults to all.',
					'enum'        => [ 'active', 'inactive', 'all' ],
					'default'     => 'all',
				],
			],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success'        => [ 'type' => 'boolean' ],
				'plugins'        => [
					'type'  => 'array',
					'items' => [
						'type'       => 'object',
						'properties' => [
							'file'       => [ 'type' => 'string' ],
							'name'       => [ 'type' => 'string' ],
							'version'    => [ 'type' => 'string' ],
							'status'     => [ 'type' => 'string' ],
							'author'     => [ 'type' => 'string' ],
							'plugin_uri' => [ 'type' => 'string' ],
						],
					],
				],
				'active_count'   => [ 'type' => 'integer' ],
				'inactive_count' => [ 'type' => 'integer' ],
				'error'          => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'activate_plugins' );
		},
		'execute_callback' => function ( $params ) {
			if ( ! function_exists( 'get_plugins' ) ) {
				require_once ABSPATH . 'wp-admin/includes/plugin.php';
			}

			$status_filter  = isset( $params['status'] ) ? sanitize_key( $params['status'] ) : 'all';
			$all_plugins    = get_plugins();
			$active_plugins = (array) get_option( 'active_plugins', [] );

			$plugins        = [];
			$active_count   = 0;
			$inactive_count = 0;

			foreach ( $all_plugins as $file => $data ) {
				$is_active = in_array( $file, $active_plugins, true );

				if ( $is_active ) {
					$active_count++;
				} else {
					$inactive_count++;
				}

				$plugin_status = $is_active ? 'active' : 'inactive';

				if ( 'all' !== $status_filter && $plugin_status !== $status_filter ) {
					continue;
				}

				$plugins[] = [
					'file'       => $file,
					'name'       => $data['Name'],
					'version'    => $data['Version'],
					'status'     => $plugin_status,
					'author'     => wp_strip_all_tags( $data['Author'] ),
					'plugin_uri' => $data['PluginURI'],
				];
			}

			return [
				'success'        => true,
				'plugins'        => $plugins,
				'active_count'   => $active_count,
				'inactive_count' => $inactive_count,
			];
		},
	] );

	// ─────────────────────────────────────────────────────────────────────────
	// PHASE 3 — Options Write Abilities
	// ─────────────────────────────────────────────────────────────────────────

	// ── ai-ddtk/update-options ───────────────────────────────────────────────
	wp_register_ability( 'ai-ddtk/update-options', [
		'label'       => 'Update Options',
		'description' => 'Write one or more WordPress options to wp_options. Dangerous keys (siteurl, home, template, stylesheet, admin_email) require confirm_dangerous: true. Plugin activation keys (active_plugins, active_sitewide_plugins) are always refused.',
		'category'    => 'site',
		'meta'        => [ 'mcp' => [ 'public' => true ] ],
		'input_schema' => [
			'type'       => 'object',
			'required'   => [ 'updates' ],
			'properties' => [
				'updates' => [
					'type'        => 'object',
					'description' => 'Key/value pairs of option names and their new values. Each value must be a string, number, boolean, array, or null.',
				],
				'autoload' => [
					'type'        => 'string',
					'description' => 'Autoload hint applied to every key in this call: "yes", "no", or "unchanged" (default "unchanged").',
					'enum'        => [ 'yes', 'no', 'unchanged' ],
					'default'     => 'unchanged',
				],
				'confirm_dangerous' => [
					'type'        => 'boolean',
					'description' => 'Must be true to write blocklisted-but-writable keys (siteurl, home, template, stylesheet, admin_email). Has no effect on always-refused keys (active_plugins, active_sitewide_plugins).',
					'default'     => false,
				],
				'redact_values' => [
					'type'        => 'boolean',
					'description' => 'When true, previous_value and new_value in each result are replaced with "[REDACTED]". Use when writing options that may contain secrets (API keys, SMTP credentials, license keys) to prevent leaking sensitive values into MCP transcripts or agent context.',
					'default'     => false,
				],
			],
		],
		'output_schema' => [
			'type'       => 'object',
			'properties' => [
				'success'               => [ 'type' => 'boolean' ],
				'results'               => [
					'type'  => 'array',
					'items' => [
						'type'       => 'object',
						'properties' => [
							'key'            => [ 'type' => 'string' ],
							'previous_value' => [],
							'new_value'      => [],
							'changed'        => [ 'type' => 'boolean' ],
						],
					],
				],
				'dangerous_keys_present' => [ 'type' => 'boolean' ],
				'blocked_keys'           => [ 'type' => 'array', 'items' => [ 'type' => 'string' ] ],
				'error'                  => [ 'type' => 'string' ],
			],
		],
		'permission_callback' => function () {
			return current_user_can( 'manage_options' );
		},
		'execute_callback' => function ( $params ) {
			if ( empty( $params['updates'] ) || ! is_array( $params['updates'] ) ) {
				return [ 'success' => false, 'error' => 'The "updates" parameter is required and must be a non-empty object.' ];
			}

			$confirm_dangerous = ! empty( $params['confirm_dangerous'] );
			$redact_values     = ! empty( $params['redact_values'] );
			$autoload_hint     = isset( $params['autoload'] ) ? $params['autoload'] : 'unchanged';

			$blocklist       = _ai_ddtk_options_blocklist();
			$always_refuse   = $blocklist['always_refuse'];
			$require_confirm = $blocklist['require_confirm'];

			// Pre-flight: collect any always-refused or unconfirmed dangerous keys.
			$refused_keys        = [];
			$unconfirmed_keys    = [];
			$dangerous_keys_seen = false;

			foreach ( array_keys( $params['updates'] ) as $key ) {
				$key = sanitize_text_field( (string) $key );
				if ( in_array( $key, $always_refuse, true ) ) {
					$refused_keys[] = $key;
				} elseif ( in_array( $key, $require_confirm, true ) ) {
					$dangerous_keys_seen = true;
					if ( ! $confirm_dangerous ) {
						$unconfirmed_keys[] = $key;
					}
				}
			}

			// Hard stop: always-refused keys present.
			if ( ! empty( $refused_keys ) ) {
				return [
					'success'                => false,
					'blocked_keys'           => $refused_keys,
					'dangerous_keys_present' => true,
					'error'                  => sprintf(
						'The following option keys can never be written via this ability: %s. Use WP-CLI (local_wp_run plugin activate/deactivate) for plugin activation state changes.',
						implode( ', ', $refused_keys )
					),
				];
			}

			// Soft stop: dangerous keys present but confirm_dangerous not set.
			if ( ! empty( $unconfirmed_keys ) ) {
				return [
					'success'                => false,
					'blocked_keys'           => $unconfirmed_keys,
					'dangerous_keys_present' => true,
					'error'                  => sprintf(
						'The following option keys require "confirm_dangerous": true before writing: %s. These keys can break site URL routing or change the active theme.',
						implode( ', ', $unconfirmed_keys )
					),
				];
			}

			// Value validation for dangerous keys (only reached when confirm_dangerous is true).
			if ( $confirm_dangerous && $dangerous_keys_seen ) {
				$validation_errors = [];
				$url_keys          = [ 'siteurl', 'home' ];
				$theme_keys        = [ 'template', 'stylesheet' ];
				$email_keys        = [ 'admin_email' ];

				foreach ( $params['updates'] as $raw_key => $new_value ) {
					$key = sanitize_text_field( (string) $raw_key );

					// URL keys must be well-formed URLs.
					if ( in_array( $key, $url_keys, true ) ) {
						$sanitized_url = esc_url_raw( (string) $new_value );
						if ( empty( $sanitized_url ) || ! wp_http_validate_url( $sanitized_url ) ) {
							$validation_errors[] = sprintf( '"%s" value "%s" is not a valid URL.', $key, (string) $new_value );
						}
					}

					// Theme keys must match an installed theme directory.
					if ( in_array( $key, $theme_keys, true ) ) {
						$installed_themes = wp_get_themes();
						$theme_slug       = sanitize_text_field( (string) $new_value );
						if ( ! isset( $installed_themes[ $theme_slug ] ) ) {
							$valid_slugs         = array_keys( $installed_themes );
							$validation_errors[] = sprintf(
								'"%s" value "%s" does not match any installed theme. Installed themes: %s.',
								$key,
								$theme_slug,
								implode( ', ', array_slice( $valid_slugs, 0, 10 ) )
							);
						}
					}

					// Email keys must be valid email addresses.
					if ( in_array( $key, $email_keys, true ) ) {
						$sanitized_email = sanitize_email( (string) $new_value );
						if ( empty( $sanitized_email ) || ! is_email( $sanitized_email ) ) {
							$validation_errors[] = sprintf( '"%s" value "%s" is not a valid email address.', $key, (string) $new_value );
						}
					}
				}

				if ( ! empty( $validation_errors ) ) {
					return [
						'success'                => false,
						'dangerous_keys_present' => true,
						'error'                  => 'Value validation failed for dangerous keys: ' . implode( ' ', $validation_errors ),
					];
				}
			}

			// All keys cleared — write each one.
			$results    = [];
			$skipped    = [];

			foreach ( $params['updates'] as $raw_key => $new_value ) {
				$key = sanitize_text_field( (string) $raw_key );

				// Reject empty or whitespace-only keys that survive sanitization.
				if ( '' === $key ) {
					$skipped[] = (string) $raw_key;
					continue;
				}

				$previous_value = get_option( $key );
				$is_dangerous   = in_array( $key, $require_confirm, true );

				// Resolve autoload argument.
				if ( 'yes' === $autoload_hint ) {
					$updated = update_option( $key, $new_value, true );
				} elseif ( 'no' === $autoload_hint ) {
					$updated = update_option( $key, $new_value, false );
				} else {
					$updated = update_option( $key, $new_value );
				}

				// Audit log: dangerous key overrides.
				if ( $is_dangerous && $confirm_dangerous ) {
					$user_id = get_current_user_id();
					// phpcs:ignore WordPress.PHP.DevelopmentFunctions.error_log_error_log
					error_log(
						sprintf(
							'[AI-DDTK] ai-ddtk/update-options: dangerous key "%s" overridden by user %d at %s.',
							$key,
							$user_id,
							gmdate( 'Y-m-d H:i:s' )
						)
					);
				}

				$results[] = [
					'key'            => $key,
					'previous_value' => $redact_values ? '[REDACTED]' : $previous_value,
					'new_value'      => $redact_values ? '[REDACTED]' : get_option( $key ),
					'changed'        => (bool) $updated,
				];
			}

			$response = [
				'success'                => true,
				'results'                => $results,
				'dangerous_keys_present' => $dangerous_keys_seen,
			];

			if ( ! empty( $skipped ) ) {
				$response['skipped_keys'] = $skipped;
			}

			return $response;
		},
	] );
} );
