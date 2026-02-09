const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const userSchema = new mongoose.Schema({
  username: {
    type: String,
    required: true,

    trim: true
  },
  mobileNumber: {
    type: String,
    required: true,
    unique: true,
    trim: true
  },
  secondaryMobileNumber: {
    type: String,
    default: null,
    trim: true
  },
  password: {
    type: String,
    required: true
  },
  profilePhoto: {
    type: String,
    default: ''
  },
  latitude: {
    type: Number,
    required: true
  },
  longitude: {
    type: Number,
    required: true
  },
  currentAddress: {
    address: String,
    state: String,
    pincode: String,
    latitude: Number,
    longitude: Number
  },
  nativeAddress: {
    address: String,
    state: String,
    pincode: String,
    latitude: Number,
    longitude: Number
  },
  useSameAddress: {
    type: Boolean,
    default: false
  },
  fatherName: {
    type: String,
    required: true
  },
  grandfatherName: {
    type: String,
    required: true
  },
  greatGrandfatherName: {
    type: String,
    default: null
  },
  motherName: {
    type: String,
    default: null
  },
  motherNative: {
    type: String,
    default: null
  },
  grandmotherName: {
    type: String,
    default: null
  },
  grandmotherNative: {
    type: String,
    default: null
  },
  emailId: {
    type: String,
    default: null
  },
  bloodGroup: {
    type: String,
    default: null,
    required: false,
    validate: {
      validator: function (value) {
        if (value === null || value === undefined || value === '') return true;
        return ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'].includes(value);
      },
      message: 'Blood group must be one of: A+, A-, B+, B-, AB+, AB-, O+, O-'
    }
  },
  highestQualification: {
    type: String,
    default: ''
  },
  workingDetails: {
    isWorking: {
      type: Boolean,
      default: false
    },
    isBusiness: {
      type: Boolean,
      default: false
    },
    workingMeans: String,
    companyName: String,
    position: String,
    totalYearsExperience: Number,
    professionType: String, // 'business', 'job', 'student'
    businessType: String,
    businessName: String,
    businessAddress: String, // Single address for backward compatibility
    businessAddresses: [String], // Multiple business addresses
    // Business fields
    organizationName: String,
    designation: String,
    organizationNumber: String,
    organizationAddress: String,
    // Student fields
    collegeName: String,
    studentYear: String,
    department: String
  },
  status: {
    type: String,
    enum: ['pending', 'approved', 'rejected'],
    default: 'pending'
  },
  isAdmin: {
    type: Boolean,
    default: false
  },
  fcmToken: {
    type: String,
    default: null
  },
  role: {
    type: String,
    enum: ['user', 'admin', 'super-admin'],
    default: 'user'
  },
  createdByAdmin: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  referralId: {
    type: String,
    unique: true,
    sparse: true,
    trim: true
  },
  referredByReferralId: {
    type: String,
    default: null,
    trim: true
  },
  isBlocked: {
    type: Boolean,
    default: false
  },
  token: {
    type: String,
    default: null,
    sparse: true  // Allow multiple null values
  },
  dateOfBirth: {
    type: Date,
    default: null
  },
  maritalStatus: {
    type: String,
    default: null,
    required: false,
    validate: {
      validator: function (value) {
        if (value === null || value === undefined || value === '') return true;
        return ['Married', 'Unmarried'].includes(value);
      },
      message: 'Marital status must be either Married or Unmarried'
    }
  },
  spouseName: {
    type: String,
    default: null
  },
  spouseNative: {
    type: String,
    default: null
  },
  spousePhoto: {
    type: String,
    default: null
  },
  // Education fields
  hasEducation: {
    type: Boolean,
    default: false
  },
  college: {
    type: String,
    default: null
  },
  yearOfCompletion: {
    type: String,
    default: null
  },
  course: {
    type: String,
    default: null
  },
  startYear: {
    type: String,
    default: null
  },
  endYear: {
    type: String,
    default: null
  },
  extraDegrees: [{
    degree: String,
    college: String,
    year: String
  }],
  kids: [{
    name: String,
    photo: String,
    dateOfBirth: Date,
    schoolName: String,
    standard: String
  }],
  familyPhoto: {
    type: String,
    default: null
  }
}, {
  timestamps: true
});

// Hash password before saving
userSchema.pre('save', async function (next) {
  if (!this.isModified('password')) return next();
  this.password = await bcrypt.hash(this.password, 10);
  next();
});

// Compare password method
userSchema.methods.comparePassword = async function (candidatePassword) {
  return await bcrypt.compare(candidatePassword, this.password);
};

module.exports = mongoose.model('User', userSchema);

