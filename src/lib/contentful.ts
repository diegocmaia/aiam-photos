import { createClient } from 'contentful';

// Create a client with your Contentful space and access token
export const createContentfulClient = () => {
  return createClient({
    space: import.meta.env.CONTENTFUL_SPACE_ID,
    accessToken: import.meta.env.CONTENTFUL_ACCESS_TOKEN
  });
};

// Fetch photos from a specific content type
export const fetchPhotos = async () => {
  const client = createContentfulClient();
  
  try {
    const assets = await client.getAssets();

    return assets.items.map((item) => ({
      title: item.fields.title || '',
      imageUrl: item.fields.file ? item.fields.file.url: '',
    }));
  } catch (error) {
    console.error('Error fetching photos from Contentful:', error);
    return [];
  }
};