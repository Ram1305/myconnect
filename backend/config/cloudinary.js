const { v2: cloudinary } = require("cloudinary");

const { CloudinaryStorage } = require("multer-storage-cloudinary");

const path = require("path");

const { v4: uuidv4 } = require("uuid");



require("dotenv").config();



// Validate Cloudinary environment variables

const cloudName = process.env.CLOUDINARY_CLOUD_NAME;

const apiKey = process.env.CLOUDINARY_API_KEY;

const apiSecret = process.env.CLOUDINARY_API_SECRET;



if (!cloudName || !apiKey || !apiSecret) {

  console.error("❌ [CLOUDINARY] Missing required environment variables:");

  console.error("   - CLOUDINARY_CLOUD_NAME:", cloudName ? "✓" : "✗ MISSING");

  console.error("   - CLOUDINARY_API_KEY:", apiKey ? "✓" : "✗ MISSING");

  console.error("   - CLOUDINARY_API_SECRET:", apiSecret ? "✓" : "✗ MISSING");

  console.error("   Please create a .env file in the backend directory with your Cloudinary credentials.");

  console.error("   See env.template for reference.");

}



if (cloudName === "api" || cloudName === undefined) {

  console.error("❌ [CLOUDINARY] Invalid cloud_name. 'api' is not a valid Cloudinary cloud name.");

  console.error("   Please set CLOUDINARY_CLOUD_NAME to your actual Cloudinary cloud name.");

}



cloudinary.config({

  cloud_name: cloudName,

  api_key: apiKey,

  api_secret: apiSecret,

});



const generatePublicId = (req, file, prefix) => {

  const timestamp = Date.now();

  const originalName = file.originalname.replace(/\.[^/.]+$/, "");

  const userId =

    req.params.userId ||

    req.body.userId ||

    req.params.customerId ||

    req.body.customerId ||

    req.params.vendorId ||

    req.body.vendorId ||

    req.params.employeeId ||

    req.body.employeeId ||

    uuidv4();

  return `${userId}_${prefix}_${originalName}_${timestamp}`;

};



// User Profile Image Storage (for My Connect app)

const userProfileImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "myconnect/user_profiles",

    allowed_formats: ["jpg", "jpeg", "png", "gif"],

    public_id: generatePublicId(req, file, "profile"),

    transformation: [{ width: 500, height: 500, crop: "limit" }],

    resource_type: "image",

  }),

});



// Customer Profile Image Storage

const customerProfileImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "customer_profile_images",

    allowed_formats: ["jpg", "jpeg", "png", "gif"],

    public_id: generatePublicId(req, file, "profile"),

    transformation: [{ width: 500, height: 500, crop: "limit" }],

    resource_type: "image",

  }),

});



// Vendor Profile Image Storage

const vendorProfileImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "vendor_profile_images",

    allowed_formats: ["jpg", "jpeg", "png", "gif"],

    public_id: generatePublicId(req, file, "profile"),

    transformation: [{ width: 500, height: 500, crop: "limit" }],

    resource_type: "image",

  }),

});



// Employee Profile Image Storage

const employeeProfileImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "employee_profile_images",

    allowed_formats: ["jpg", "jpeg", "png", "gif"],

    public_id: generatePublicId(req, file, "profile"),

    transformation: [{ width: 500, height: 500, crop: "limit" }],

    resource_type: "image",

  }),

});



// Car Images Storage (for car registration)

const carImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "car_images",

    allowed_formats: ["jpg", "jpeg", "png", "gif"],

    public_id: generatePublicId(req, file, "car"),

    transformation: [{ width: 800, height: 600, crop: "limit" }],

    resource_type: "image",

  }),

});



// Booking Images Storage (4-side car images: front, back, left, right)

const bookingImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => {

    const side = req.body.side || req.query.side || "unknown"; // front, back, left, right

    const type = req.body.type || req.query.type || "before"; // before, after

    return {

      folder: `booking_images/${side}/${type}`,

      allowed_formats: ["jpg", "jpeg", "png", "gif"],

      public_id: (req, file) => {

        const bookingId = req.params.bookingId || req.body.bookingId || uuidv4();

        const timestamp = Date.now();

        return `${bookingId}_${side}_${type}_${timestamp}`;

      },

      transformation: [{ width: 1200, height: 800, crop: "limit" }],

      resource_type: "image",

    };

  },

});



// Damage Images Storage

const damageImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "damage_images",

    allowed_formats: ["jpg", "jpeg", "png", "gif"],

    public_id: generatePublicId(req, file, "damage"),

    transformation: [{ width: 1000, height: 1000, crop: "limit" }],

    resource_type: "image",

  }),

});



// Vendor Documents Storage (Address Proof, Aadhar, PAN)

const vendorDocumentStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => {

    const docType = req.body.documentType || "document"; // address_proof, aadhar, pan

    return {

      folder: `vendor_documents/${docType}`,

      allowed_formats: ["jpg", "jpeg", "png", "pdf"],

      public_id: generatePublicId(req, file, docType),

      resource_type: "auto",

    };

  },

});



// Offer/Promotion Images Storage

const offerImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "offer_images",

    allowed_formats: ["jpg", "jpeg", "png", "gif"],

    public_id: generatePublicId(req, file, "offer"),

    transformation: [{ width: 1000, height: 500, crop: "limit" }],

    resource_type: "image",

  }),

});



// Banner Images Storage (for home page carousel)

const bannerImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "myconnect/banners",

    allowed_formats: ["jpg", "jpeg", "png", "gif", "webp"],

    public_id: generatePublicId(req, file, "banner"),

    transformation: [{ width: 1200, height: 400, crop: "limit" }],

    resource_type: "image",

  }),

});



// Gallery Images Storage

const galleryImageStorage = new CloudinaryStorage({

  cloudinary: cloudinary,

  params: (req, file) => ({

    folder: "myconnect/gallery",

    allowed_formats: ["jpg", "jpeg", "png", "gif", "webp"],

    public_id: generatePublicId(req, file, "gallery"),

    transformation: [{ width: 1600, height: 1600, crop: "limit" }],

    resource_type: "image",

  }),

});



// General Image Upload Function

const uploadImage = async (imageBuffer, folder) => {

  // Validate Cloudinary configuration before upload

  if (!cloudName || !apiKey || !apiSecret) {

    throw new Error("Cloudinary is not configured. Please set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in your .env file.");

  }



  if (cloudName === "api" || cloudName === undefined) {

    throw new Error("Invalid Cloudinary cloud_name. Please set CLOUDINARY_CLOUD_NAME to your actual Cloudinary cloud name (not 'api').");

  }



  return new Promise((resolve, reject) => {

    cloudinary.uploader

      .upload_stream(

        {

          folder: folder,

          resource_type: "auto",

        },

        (error, result) => {

          if (error) {

            console.error("❌ [CLOUDINARY] Upload error:", error);

            return reject(

              new Error("Cloudinary upload failed: " + error.message)

            );

          }

          resolve(result.secure_url);

        }

      )

      .end(imageBuffer);

  });

};



// Delete Image Function

const deleteImage = async (publicId) => {

  try {

    const result = await cloudinary.uploader.destroy(publicId);

    return result;

  } catch (error) {

    throw new Error("Cloudinary delete failed: " + error.message);

  }

};



module.exports = {

  cloudinary,

  uploadImage,

  deleteImage,

  userProfileImageStorage,

  customerProfileImageStorage,

  vendorProfileImageStorage,

  employeeProfileImageStorage,

  carImageStorage,

  bookingImageStorage,

  damageImageStorage,

  vendorDocumentStorage,

  offerImageStorage,

  bannerImageStorage,

  galleryImageStorage,

};

