// MCP Server Test Script
// This script tests a local MCP server running on port 8000

// Import required modules
const http = require('http');
const assert = require('assert');

// Server configuration
const HOST = 'localhost';
const PORT = 8000;
const BASE_URL = `http://${HOST}:${PORT}`;

// Utility function to make HTTP requests
function makeRequest(method, path, data = null) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: HOST,
      port: PORT,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          // Try to parse as JSON if possible
          const parsedData = responseData ? JSON.parse(responseData) : {};
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: parsedData
          });
        } catch (e) {
          // Return raw data if not JSON
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: responseData
          });
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    if (data) {
      req.write(JSON.stringify(data));
    }
    
    req.end();
  });
}

// Test cases
const tests = {
  // Test basic server connectivity
  testServerConnectivity: async () => {
    console.log('\n🔍 Testing basic server connectivity...');
    try {
      const response = await makeRequest('GET', '/');
      assert.strictEqual(response.statusCode, 200, 'Server should respond with 200 OK');
      console.log('✅ Server is reachable and responding');
      return true;
    } catch (error) {
      console.error('❌ Server connectivity test failed:', error.message);
      return false;
    }
  },
  
  // Test MCP API endpoints
  testAPIEndpoints: async () => {
    console.log('\n🔍 Testing API endpoints...');
    try {
      // Test GET endpoint
      const getResponse = await makeRequest('GET', '/api/status');
      assert.strictEqual(getResponse.statusCode, 200, 'GET /api/status should return 200');
      console.log('✅ GET /api/status: OK');
      
      // Test POST endpoint with sample data
      const testData = { message: 'test message', priority: 'high' };
      const postResponse = await makeRequest('POST', '/api/messages', testData);
      assert.strictEqual(postResponse.statusCode, 201, 'POST /api/messages should return 201');
      console.log('✅ POST /api/messages: OK');
      
      // Test PUT endpoint
      const putResponse = await makeRequest('PUT', '/api/messages/1', { status: 'processed' });
      assert.strictEqual(putResponse.statusCode, 200, 'PUT /api/messages/1 should return 200');
      console.log('✅ PUT /api/messages/1: OK');
      
      // Test DELETE endpoint
      const deleteResponse = await makeRequest('DELETE', '/api/messages/1');
      assert.strictEqual(deleteResponse.statusCode, 200, 'DELETE /api/messages/1 should return 200');
      console.log('✅ DELETE /api/messages/1: OK');
      
      return true;
    } catch (error) {
      console.error('❌ API endpoints test failed:', error.message);
      return false;
    }
  },
  
  // Test error handling
  testErrorHandling: async () => {
    console.log('\n🔍 Testing error handling...');
    try {
      // Test non-existent endpoint
      const notFoundResponse = await makeRequest('GET', '/not-found');
      assert.strictEqual(notFoundResponse.statusCode, 404, 'Non-existent endpoint should return 404');
      console.log('✅ 404 handling: OK');
      
      // Test malformed request
      const malformedData = 'This is not JSON';
      const badRequestResponse = await makeRequest('POST', '/api/messages', malformedData);
      assert.strictEqual(badRequestResponse.statusCode, 400, 'Malformed request should return 400');
      console.log('✅ 400 handling: OK');
      
      return true;
    } catch (error) {
      console.error('❌ Error handling test failed:', error.message);
      return false;
    }
  },
  
  // Test server performance with multiple requests
  testPerformance: async () => {
    console.log('\n🔍 Testing server performance...');
    try {
      const startTime = Date.now();
      const requests = [];
      const requestCount = 10;
      
      for (let i = 0; i < requestCount; i++) {
        requests.push(makeRequest('GET', '/api/status'));
      }
      
      await Promise.all(requests);
      const endTime = Date.now();
      const duration = endTime - startTime;
      const avgResponseTime = duration / requestCount;
      
      console.log(`✅ Performance test completed. ${requestCount} requests processed in ${duration}ms`);
      console.log(`✅ Average response time: ${avgResponseTime.toFixed(2)}ms per request`);
      
      return true;
    } catch (error) {
      console.error('❌ Performance test failed:', error.message);
      return false;
    }
  }
};

// Run all tests
async function runTests() {
  console.log('🚀 Starting MCP server tests on ' + BASE_URL);
  
  // Check if server is running first
  if (!await tests.testServerConnectivity()) {
    console.error('❌ Cannot connect to server. Make sure it is running on ' + BASE_URL);
    process.exit(1);
  }
  
  // Run remaining tests
  const results = {
    apiEndpoints: await tests.testAPIEndpoints(),
    errorHandling: await tests.testErrorHandling(),
    performance: await tests.testPerformance()
  };
  
  // Print summary
  console.log('\n📊 Test Summary:');
  console.log('----------------');
  console.log(`Server Connectivity: ${results.serverConnectivity ? 'PASSED' : 'FAILED'}`);
  console.log(`API Endpoints: ${results.apiEndpoints ? 'PASSED' : 'FAILED'}`);
  console.log(`Error Handling: ${results.errorHandling ? 'PASSED' : 'FAILED'}`);
  console.log(`Performance: ${results.performance ? 'PASSED' : 'FAILED'}`);
  
  const allPassed = Object.values(results).every(result => result === true);
  console.log('\n' + (allPassed ? '🎉 All tests PASSED!' : '❌ Some tests FAILED!'));
}

// Execute all tests
runTests().catch(error => {
  console.error('Test execution error:', error);
});
