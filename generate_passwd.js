const argon2 = require('/opt/key-networks/ztncui/node_modules/argon2');

(async () => {
  try {
    const hash = await argon2.hash('admin');
    const passwd = { admin: { name: 'admin', pass_set: false, hash: hash } };
    console.log(JSON.stringify(passwd));
  } catch (err) {
    console.error('Error:', err);
    process.exit(1);
  }
})();
