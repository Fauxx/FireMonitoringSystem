const { ensureAuthenticated } = require('../src/middleware/auth');

describe('ensureAuthenticated middleware', () => {
  const mockRes = () => {
    const res = {};
    res.setHeader = jest.fn();
    res.redirect = jest.fn();
    return res;
  };

  test('calls next() when session has user', () => {
    const req = { session: { user: { id: 1, username: 'test' } } };
    const res = mockRes();
    const next = jest.fn();

    ensureAuthenticated(req, res, next);

    expect(next).toHaveBeenCalled();
    expect(res.setHeader).toHaveBeenCalledWith('Cache-Control', 'no-store');
  });

  test('redirects to login when no session', () => {
    const req = { session: {} };
    const res = mockRes();
    const next = jest.fn();

    ensureAuthenticated(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.redirect).toHaveBeenCalledWith('/login.html');
  });

  test('redirects to login when session is null', () => {
    const req = {};
    const res = mockRes();
    const next = jest.fn();

    ensureAuthenticated(req, res, next);

    expect(next).not.toHaveBeenCalled();
    expect(res.redirect).toHaveBeenCalledWith('/login.html');
  });
});
