const { S3Client } = require('@aws-sdk/client-s3');

const readEnvValue = (value) => {
  if (typeof value !== 'string') {
    return value;
  }

  const trimmed = value.trim();
  if (
    (trimmed.startsWith('"') && trimmed.endsWith('"')) ||
    (trimmed.startsWith("'") && trimmed.endsWith("'"))
  ) {
    return trimmed.slice(1, -1);
  }

  return trimmed;
};

const getBucket = () => readEnvValue(process.env.AWS_S3_BUCKET);
const getRegion = () => readEnvValue(process.env.AWS_REGION);

const buildAwsCredentials = () => {
  const accessKeyId = readEnvValue(process.env.AWS_ACCESS_KEY_ID || process.env.AWS_KEY_ID);
  const secretAccessKey = readEnvValue(process.env.AWS_SECRET_ACCESS_KEY || process.env.AWS_SECRET_KEY);

  if (accessKeyId && secretAccessKey) {
    return { accessKeyId, secretAccessKey };
  }

  return undefined;
};

const s3Client = new S3Client({
  region: getRegion(),
  credentials: buildAwsCredentials(),
});

const buildPublicUrl = (key) => {
  if (!key) {
    return null;
  }

  if (/^https?:\/\//i.test(key)) {
    return key;
  }

  const cdnBase = readEnvValue(process.env.AWS_CDN_URL)?.replace(/\/$/, '');
  if (cdnBase) {
    return `${cdnBase}/${key}`;
  }

  const bucket = getBucket();
  const region = getRegion();
  if (!bucket || !region) {
    return key;
  }

  return `https://${bucket}.s3.${region}.amazonaws.com/${key}`;
};

module.exports = {
  s3Client,
  buildPublicUrl,
  getBucket,
};
