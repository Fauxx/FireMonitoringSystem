
const bcrypt = require('bcrypt');

(async () => {
  const password = "admin";
  const saltRounds = 10;
  const hashedPassword = await bcrypt.hash(password, saltRounds);
  console.log(`Hashed Password for "${password}":`, hashedPassword);
  
  // Also generate one for "password123" 
  const password2 = "password123";
  const hashedPassword2 = await bcrypt.hash(password2, saltRounds);
  console.log(`Hashed Password for "${password2}":`, hashedPassword2);
})();
