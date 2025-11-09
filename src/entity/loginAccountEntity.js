export function loginAccountEntity(formData) {
  const { email, password } = formData;

  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

  function validate() {
    if (!email.trim()) return "Email is required.";
    if (!emailRegex.test(email)) return "Invalid email format.";
    if (!password.trim()) return "Password is required.";
    return null;
  }

  return {
    email: email.trim(),
    password,
    validate,
  };
}
