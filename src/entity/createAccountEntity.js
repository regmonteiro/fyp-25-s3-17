export function createAccountEntity(formData) {
  const { firstname, lastname, email, dob, phoneNum, password, confirmPassword, userType, elderlyId } = formData;

  const nameRegex = /^[A-Za-z\s]+$/;
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  const today = new Date().toISOString().split('T')[0];

  function validate() {
    if (!firstname.trim()) return "First name is required.";
    if (!nameRegex.test(firstname)) return "First name must only contain letters.";
    if (!lastname.trim()) return "Last name is required.";
    if (!nameRegex.test(lastname)) return "Last name must only contain letters.";
    if (!email.trim()) return "Email is required.";
    if (!emailRegex.test(email)) return "Email format is invalid.";
    if (!dob) return "Date of birth is required.";
    if (dob > today) return "Date of birth cannot be in the future.";
    if (!phoneNum.trim()) return "Phone number is required.";
    if (password.length < 8) return "Password must be at least 8 characters.";
    if (password !== confirmPassword) return "Passwords do not match.";

    // Elderly ID required if caregiver
    if (userType === 'caregiver' && (!elderlyId || !elderlyId.trim())) {
      return "Elderly email is required for caregiver accounts.";
    }

    return null;
  }

  return {
    firstname,
    lastname,
    email,
    dob,
    phoneNum,
    password,
    confirmPassword,
    userType,
    elderlyId: userType === 'caregiver' ? elderlyId.trim() : null,
    validate,
  };
}
