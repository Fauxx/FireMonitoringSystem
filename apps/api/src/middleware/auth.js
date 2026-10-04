function ensureAuthenticated(req, res, next) {
  if (req.session && req.session.user) {
    res.setHeader('Cache-Control', 'no-store'); // prevent caching
    return next();
  } else {
    if (req.originalUrl.startsWith('/api') || req.xhr || req.headers.accept?.includes('application/json')) {
      return res.status(401).json({ error: 'Authentication required' });
    }
    return res.redirect('/login.html');
  }
}

module.exports = {
  ensureAuthenticated
};
