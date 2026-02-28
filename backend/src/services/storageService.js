const {
    S3Client,
    PutObjectCommand,
    DeleteObjectCommand,
    GetObjectCommand,
    ListObjectsV2Command,
} = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

// Backblaze B2 is S3-compatible — point endpoint to your B2 region
const s3 = new S3Client({
    endpoint: process.env.B2_ENDPOINT,           // e.g. https://s3.us-west-004.backblazeb2.com
    region: process.env.B2_REGION || 'us-west-004',
    credentials: {
        accessKeyId: process.env.B2_KEY_ID,
        secretAccessKey: process.env.B2_APP_KEY,
    },
    forcePathStyle: true,                        // Required for B2
});

const BUCKET = process.env.B2_BUCKET || 'survival-vault';

/**
 * Build the B2 object key. Structure:
 *   {userId}/{category}/{fileId}/{originalFileName}
 * This makes it trivially easy to list all files for a user or per category.
 */
const buildStorageKey = (userId, category, fileId, fileName) =>
    `${userId}/${category}/${fileId}/${fileName}`;

/**
 * Generate a presigned URL for the client to upload a file directly to B2.
 * The API server never handles the raw bytes — only the metadata.
 * @returns {{ uploadUrl: string, storageKey: string }}
 */
const generateUploadUrl = async (userId, category, fileId, fileName, contentType, fileSizeBytes) => {
    const MAX_MB = parseInt(process.env.VAULT_MAX_FILE_SIZE_MB || '500', 10);
    if (fileSizeBytes > MAX_MB * 1024 * 1024) {
        throw new Error(`File too large. Maximum allowed size is ${MAX_MB} MB.`);
    }

    const storageKey = buildStorageKey(userId, category, fileId, fileName);

    const command = new PutObjectCommand({
        Bucket: BUCKET,
        Key: storageKey,
        ContentType: contentType || 'application/octet-stream',
        ContentLength: fileSizeBytes,
        // Tag each object with metadata for easy admin searches
        Tagging: `userId=${userId}&category=${encodeURIComponent(category)}`,
    });

    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 15 * 60 }); // 15 min TTL
    return { uploadUrl, storageKey };
};

/**
 * Generate a presigned URL to download (GET) a file.
 * The server verifies ownership before issuing this URL.
 * @returns {string} signed download URL (1 hour TTL)
 */
const generateDownloadUrl = async (storageKey) => {
    const command = new GetObjectCommand({ Bucket: BUCKET, Key: storageKey });
    return getSignedUrl(s3, command, { expiresIn: 60 * 60 }); // 1 hour TTL
};

/**
 * Delete a file from B2 storage permanently.
 */
const deleteFile = async (storageKey) => {
    const command = new DeleteObjectCommand({ Bucket: BUCKET, Key: storageKey });
    await s3.send(command);
};

/**
 * Admin utility: list all B2 objects under a given prefix.
 * Prefix can be:  "{userId}/"          → all files for a user
 *                 "{userId}/{category}/" → files in a specific category
 */
const listAdminObjects = async (prefix) => {
    const command = new ListObjectsV2Command({ Bucket: BUCKET, Prefix: prefix });
    const response = await s3.send(command);
    return (response.Contents || []).map((obj) => ({
        key: obj.Key,
        size: obj.Size,
        lastModified: obj.LastModified,
    }));
};

module.exports = {
    generateUploadUrl,
    generateDownloadUrl,
    deleteFile,
    listAdminObjects,
    buildStorageKey,
};
