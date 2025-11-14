// src/entity/createAccountEntity.js
export function createAccountEntity(accountData) {
  const {
    firstname,
    lastname,
    email,
    dob,
    phoneNum,
    password,
    userType,
    elderlyIds = [],   // now an array
    subscriptionPlan,
    subscriptionEndDate,
    paymentDetails
  } = accountData;

  function validate() {
    if (!firstname || !lastname || !email || !dob || !phoneNum || !password || !userType) {
      return "All fields are required";
    }

    if (!isValidEmail(email)) {
      return "Please enter a valid email address";
    }

    if (password.length < 8) {
      return "Password must be at least 8 characters long";
    }

    if (userType === "caregiver") {
      if (!Array.isArray(elderlyIds)) {
        return "elderlyIds must be an array";
      }
      for (const id of elderlyIds) {
        if (id && !isValidEmail(id)) {
          return `Invalid elderly email: ${id}`;
        }
      }
    }

    return null;
  }

  function isValidEmail(email) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  }

  return {
    firstname: firstname.trim(),
    lastname: lastname.trim(),
    email: email.trim().toLowerCase(),
    dob,
    phoneNum,
    password,
    userType,
    elderlyIds: Array.isArray(elderlyIds)
      ? elderlyIds.map(e => e.trim().toLowerCase())
      : [],
    subscriptionPlan,
    subscriptionEndDate,
    paymentDetails,
    validate
  };
}
