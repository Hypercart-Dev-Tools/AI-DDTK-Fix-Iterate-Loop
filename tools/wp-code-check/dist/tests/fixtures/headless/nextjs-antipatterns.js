/**
 * Headless WordPress Anti-patterns: Next.js Data Fetching
 * 
 * This fixture contains common anti-patterns in Next.js when fetching
 * data from WordPress (via REST API or WPGraphQL).
 * 
 * Expected violations: 6
 * Expected safe patterns: 4
 */

// =============================================================================
// ANTI-PATTERNS (Should be flagged)
// =============================================================================

// VIOLATION 1: getStaticProps without revalidate (stale data forever)
export async function getStaticProps() {
  const posts = await fetch('https://example.com/wp-json/wp/v2/posts');
  const data = await posts.json();
  
  return {
    props: { posts: data },
    // Missing: revalidate property - data will be stale forever
  };
}

// VIOLATION 2: getStaticProps without error handling
export async function getStaticPropsNoError() {
  const res = await fetch(`${process.env.WORDPRESS_URL}/wp-json/wp/v2/pages`);
  const pages = await res.json();
  
  return {
    props: { pages },
    revalidate: 60,
  };
}

// VIOLATION 3: GraphQL query without error handling
import { useQuery } from '@apollo/client';
import { GET_POSTS } from '../queries';

function PostsComponent() {
  const { data, loading } = useQuery(GET_POSTS);
  // Missing: error handling, onError callback, or errorPolicy
  
  if (loading) return <p>Loading...</p>;
  return <div>{data.posts.map(p => <p key={p.id}>{p.title}</p>)}</div>;
}

// VIOLATION 4: useSWR without error handling
import useSWR from 'swr';

function SWRComponent() {
  const { data } = useSWR('/api/posts', fetcher);
  // Missing: error state handling
  
  return <div>{data?.map(p => <p>{p.title}</p>)}</div>;
}

// VIOLATION 5: Hardcoded WordPress URL in getServerSideProps
export async function getServerSideProps() {
  const res = await fetch('https://wordpress.mysite.com/wp-json/wp/v2/posts');
  const posts = await res.json();
  
  return { props: { posts } };
}

// VIOLATION 6: Missing fallback in getStaticPaths for WordPress posts
export async function getStaticPaths() {
  const res = await fetch(`${process.env.WORDPRESS_URL}/wp-json/wp/v2/posts`);
  const posts = await res.json();
  
  return {
    paths: posts.map(post => ({ params: { slug: post.slug } })),
    // Missing: fallback: 'blocking' or fallback: true for new posts
    fallback: false, // New WordPress posts won't generate pages!
  };
}

// =============================================================================
// SAFE PATTERNS (Should NOT be flagged)
// =============================================================================

// SAFE 1: getStaticProps with revalidate (ISR)
export async function getStaticPropsSafe() {
  try {
    const res = await fetch(`${process.env.WORDPRESS_URL}/wp-json/wp/v2/posts`);
    if (!res.ok) throw new Error('Failed to fetch posts');
    const posts = await res.json();
    
    return {
      props: { posts },
      revalidate: 60, // Revalidate every 60 seconds
    };
  } catch (error) {
    return {
      props: { posts: [], error: 'Failed to load posts' },
      revalidate: 10,
    };
  }
}

// SAFE 2: useQuery with error handling
function PostsComponentSafe() {
  const { data, loading, error } = useQuery(GET_POSTS, {
    onError: (error) => console.error('GraphQL Error:', error),
    errorPolicy: 'all',
  });
  
  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;
  return <div>{data.posts.map(p => <p key={p.id}>{p.title}</p>)}</div>;
}

// SAFE 3: useSWR with error handling
function SWRComponentSafe() {
  const { data, error, isLoading } = useSWR('/api/posts', fetcher);
  
  if (isLoading) return <p>Loading...</p>;
  if (error) return <p>Error loading posts</p>;
  return <div>{data?.map(p => <p key={p.id}>{p.title}</p>)}</div>;
}

// SAFE 4: getStaticPaths with fallback: 'blocking'
export async function getStaticPathsSafe() {
  const res = await fetch(`${process.env.WORDPRESS_URL}/wp-json/wp/v2/posts`);
  const posts = await res.json();
  
  return {
    paths: posts.map(post => ({ params: { slug: post.slug } })),
    fallback: 'blocking', // New posts will SSR on first request
  };
}

