/**
 * Headless WordPress Anti-patterns: WPGraphQL / Apollo Client
 * 
 * This fixture contains common anti-patterns when using WPGraphQL
 * with Apollo Client, URQL, or other GraphQL clients.
 * 
 * Expected violations: 6
 * Expected safe patterns: 4
 */

import { gql, useQuery, useMutation } from '@apollo/client';

// =============================================================================
// ANTI-PATTERNS (Should be flagged)
// =============================================================================

// VIOLATION 1: useQuery without error handling
const GET_POSTS = gql`
  query GetPosts {
    posts { nodes { id title } }
  }
`;

function PostsNoError() {
  const { data, loading } = useQuery(GET_POSTS);
  // Missing: error state, onError callback
  
  if (loading) return <p>Loading...</p>;
  return <div>{data?.posts?.nodes?.map(p => <p>{p.title}</p>)}</div>;
}

// VIOLATION 2: useMutation without error handling
const CREATE_POST = gql`
  mutation CreatePost($input: CreatePostInput!) {
    createPost(input: $input) { post { id } }
  }
`;

function CreatePostNoError() {
  const [createPost, { loading }] = useMutation(CREATE_POST);
  // Missing: error handling, onError callback
  
  const handleSubmit = () => {
    createPost({ variables: { input: { title: 'New Post' } } });
    // No error handling if mutation fails
  };
  
  return <button onClick={handleSubmit}>Create</button>;
}

// VIOLATION 3: GraphQL query with hardcoded endpoint
const client = new ApolloClient({
  uri: 'https://mywordpress.com/graphql',
  // Hardcoded URL instead of environment variable
  cache: new InMemoryCache(),
});

// VIOLATION 4: No error boundary around GraphQL components
function App() {
  return (
    <ApolloProvider client={client}>
      {/* Missing: ErrorBoundary wrapper */}
      <PostsNoError />
    </ApolloProvider>
  );
}

// VIOLATION 5: fetchPolicy with no cache strategy consideration
function PostsNoCache() {
  const { data } = useQuery(GET_POSTS, {
    fetchPolicy: 'network-only', // Always hits server, no caching benefit
  });
  // Missing: Error handling AND inefficient fetch policy
  return <div>{data?.posts?.nodes?.length}</div>;
}

// VIOLATION 6: Missing authentication in GraphQL client setup
const unauthenticatedClient = new ApolloClient({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL,
  cache: new InMemoryCache(),
  // Missing: credentials, headers for authenticated queries
});

// =============================================================================
// SAFE PATTERNS (Should NOT be flagged)
// =============================================================================

// SAFE 1: useQuery with full error handling
function PostsSafe() {
  const { data, loading, error } = useQuery(GET_POSTS, {
    onError: (error) => {
      console.error('GraphQL query failed:', error);
      // Could also send to error tracking service
    },
    errorPolicy: 'all', // Return partial data if possible
  });
  
  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;
  return <div>{data?.posts?.nodes?.map(p => <p key={p.id}>{p.title}</p>)}</div>;
}

// SAFE 2: useMutation with error handling
function CreatePostSafe() {
  const [createPost, { loading, error }] = useMutation(CREATE_POST, {
    onError: (error) => {
      console.error('Failed to create post:', error);
      alert('Failed to create post. Please try again.');
    },
    onCompleted: (data) => {
      console.log('Post created:', data.createPost.post.id);
    },
  });
  
  const handleSubmit = async () => {
    try {
      await createPost({ variables: { input: { title: 'New Post' } } });
    } catch (e) {
      // Error already handled by onError
    }
  };
  
  return (
    <>
      <button onClick={handleSubmit} disabled={loading}>Create</button>
      {error && <p className="error">{error.message}</p>}
    </>
  );
}

// SAFE 3: Apollo Client with proper auth setup
const authenticatedClient = new ApolloClient({
  uri: process.env.NEXT_PUBLIC_GRAPHQL_URL,
  cache: new InMemoryCache(),
  credentials: 'include',
  headers: {
    'Authorization': `Bearer ${typeof window !== 'undefined' ? localStorage.getItem('token') : ''}`,
  },
});

// SAFE 4: With ErrorBoundary
function AppSafe() {
  return (
    <ErrorBoundary fallback={<p>Something went wrong</p>}>
      <ApolloProvider client={authenticatedClient}>
        <PostsSafe />
      </ApolloProvider>
    </ErrorBoundary>
  );
}

