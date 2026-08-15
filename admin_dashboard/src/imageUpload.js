import { api } from './apiClient';

/**
 * Uploads an image file to Cloudinary via the backend.
 * @param {File} file - The image file to upload.
 * @param {string} folder - The folder to organize the upload under (products/categories/banners/general).
 * @returns {Promise<string>} The public Cloudinary URL of the uploaded image.
 */
export const uploadImage = async (file, folder = 'general') => {
  if (!file) return null;

  const formData = new FormData();
  formData.append('file', file);
  formData.append('folder', folder);

  const data = await api.postForm('/upload', formData);
  return data.url;
};

/**
 * Deletes an image from Cloudinary based on its public URL.
 * @param {string} imageUrl - The full Cloudinary URL of the image.
 */
export const deleteImage = async (imageUrl) => {
  if (!imageUrl || !imageUrl.includes('cloudinary.com')) return;
  try {
    await api.delete('/upload', { url: imageUrl });
  } catch (err) {
    console.error('Error deleting image:', err);
  }
};
