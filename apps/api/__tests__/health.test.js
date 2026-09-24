const http = require('http');
const express = require('express');

describe('Health endpoint', () => {
  let server;
  let app;

  beforeAll((done) => {
    app = express();
    app.get('/health', (req, res) => res.status(200).send('healthy'));
    server = app.listen(0, () => done());
  });

  afterAll((done) => {
    server.close(() => done());
  });

  test('GET /health returns 200', async () => {
    const { port } = server.address();
    const res = await fetch(`http://127.0.0.1:${port}/health`);
    expect(res.status).toBe(200);
    expect(await res.text()).toBe('healthy');
  });
});
