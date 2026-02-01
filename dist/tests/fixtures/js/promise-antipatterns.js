/**
 * JavaScript Promise Anti-patterns Test Fixture
 * 
 * This file contains promise/async handling violations for testing WP Code Check detection.
 * DO NOT use these patterns in production code!
 * 
 * @package WP_Code_Check
 * @subpackage Tests/Fixtures/JS
 * @since 1.0.81
 */

// =============================================================================
// UNHANDLED PROMISE REJECTIONS
// =============================================================================

// VIOLATION 1: Promise without .catch()
function fetchDataNoCatch() {
  fetch('/api/data')
    .then(res => res.json())
    .then(data => processData(data));
  // Missing: .catch(error => handleError(error))
}

// VIOLATION 2: Promise.all without .catch()
function fetchMultipleNoCatch(urls) {
  Promise.all(urls.map(url => fetch(url)))
    .then(responses => responses.map(r => r.json()));
  // Missing error handling for any failed request
}

// VIOLATION 3: async function without try/catch
async function asyncNoCatch() {
  const response = await fetch('/api/data');
  const data = await response.json();
  return data;
  // Missing: try/catch wrapper
}

// VIOLATION 4: Multiple awaits without try/catch
async function multipleAwaitsNoCatch(userId) {
  const user = await fetchUser(userId);
  const orders = await fetchOrders(user.id);
  const reviews = await fetchReviews(user.id);
  return { user, orders, reviews };
  // If any fails, unhandled rejection
}

// VIOLATION 5: new Promise executor without reject handling
function promiseNoReject() {
  return new Promise((resolve) => {
    doAsyncOperation((result) => {
      resolve(result);
    });
    // Missing: reject for error cases
  });
}

// VIOLATION 6: Floating promise (not awaited or chained)
function floatingPromise() {
  someAsyncFunction();  // Promise returned but ignored
  doSyncWork();
}

// VIOLATION 7: async void function (can't catch errors)
async function asyncVoidHandler() {
  const data = await fetchData();
  updateUI(data);
  // Errors here are uncatchable by caller
}

// VIOLATION 8: Promise in forEach (no way to await all)
function promiseInForEach(items) {
  items.forEach(async (item) => {
    await processItem(item);  // These run in parallel, errors lost
  });
  console.log('Done');  // Runs before promises complete!
}

// =============================================================================
// CALLBACK HELL / ANTI-PATTERNS
// =============================================================================

// VIOLATION 9: Deeply nested callbacks (callback hell)
function callbackHell(userId, callback) {
  getUser(userId, function(err, user) {
    if (err) return callback(err);
    getOrders(user.id, function(err, orders) {
      if (err) return callback(err);
      getPayments(orders[0].id, function(err, payments) {
        if (err) return callback(err);
        getReceipts(payments[0].id, function(err, receipts) {
          if (err) return callback(err);
          callback(null, { user, orders, payments, receipts });
        });
      });
    });
  });
}

// =============================================================================
// SAFE PATTERNS (Should NOT trigger)
// =============================================================================

// SAFE 1: Promise with .catch()
function fetchDataWithCatch() {
  fetch('/api/data')
    .then(res => res.json())
    .then(data => processData(data))
    .catch(error => {
      console.error('Fetch failed:', error);
      showErrorUI();
    });
}

// SAFE 2: async/await with try/catch
async function asyncWithTryCatch() {
  try {
    const response = await fetch('/api/data');
    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Failed:', error);
    throw error;  // Re-throw or handle appropriately
  }
}

// SAFE 3: Promise.all with .catch()
function fetchMultipleWithCatch(urls) {
  return Promise.all(urls.map(url => fetch(url)))
    .then(responses => Promise.all(responses.map(r => r.json())))
    .catch(error => {
      console.error('One or more requests failed:', error);
      return [];
    });
}

// SAFE 4: await in for...of (sequential, awaited)
async function processItemsSequentially(items) {
  for (const item of items) {
    await processItem(item);
  }
}

// SAFE 5: Promise.all with map for parallel processing
async function processItemsParallel(items) {
  await Promise.all(items.map(item => processItem(item)));
}

// SAFE 6: new Promise with proper reject
function promiseWithReject() {
  return new Promise((resolve, reject) => {
    doAsyncOperation((error, result) => {
      if (error) reject(error);
      else resolve(result);
    });
  });
}

