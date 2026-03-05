function ensureAuthenticated(req, res, next) {
  if (req.session && req.session.user) {
    res.setHeader('Cache-Control', 'no-store'); // prevent caching
    return next();
  } else {
    return res.redirect('/login.html');
  }
}

module.exports = {
  ensureAuthenticated
};
