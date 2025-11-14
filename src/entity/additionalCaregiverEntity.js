export class AdditionalCaregiverEntity {
  constructor(firstname, lastname, email, dob, phoneNum, password, confirmPassword) {
    this.firstname = firstname;
    this.lastname = lastname;
    this.email = email;
    this.dob = dob;
    this.phoneNum = phoneNum;
    this.password = password;
    this.confirmPassword = confirmPassword;
  }

  validate() {
    const errors = [];

    // First name validation
    if (!this.firstname || this.firstname.trim().length < 2) {
      errors.push("First name must be at least 2 characters long");
    }

    // Last name validation
    if (!this.lastname || this.lastname.trim().length < 2) {
      errors.push("Last name must be at least 2 characters long");
    }

    // Email validation
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!this.email || !emailRegex.test(this.email)) {
      errors.push("Please enter a valid email address");
    }

    // Date of birth validation
    if (!this.dob) {
      errors.push("Date of birth is required");
    } else {
      const dobDate = new Date(this.dob);
      const today = new Date();
      if (dobDate >= today) {
        errors.push("Date of birth must be in the past");
      }
    }

    // Phone number validation
    const phoneRegex = /^[\+]?[1-9][\d]{0,15}$/;
    if (!this.phoneNum || !phoneRegex.test(this.phoneNum.replace(/[\s\-\(\)]/g, ''))) {
      errors.push("Please enter a valid phone number");
    }

    // Password validation
    if (!this.password || this.password.length < 6) {
      errors.push("Password must be at least 6 characters long");
    }

    // Password confirmation
    if (this.password !== this.confirmPassword) {
      errors.push("Passwords do not match");
    }

    return errors.length > 0 ? errors.join(", ") : null;
  }

  toJSON() {
    return {
      firstname: this.firstname.trim(),
      lastname: this.lastname.trim(),
      email: this.email.toLowerCase().trim(),
      dob: this.dob,
      phoneNum: this.phoneNum.trim(),
      password: this.password
    };
  }
}