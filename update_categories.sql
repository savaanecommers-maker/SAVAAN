-- ============================================================
-- SAVAAN — Replace categories with full list from document
-- Run this in Supabase SQL Editor
-- ============================================================

-- Step 1: Remove old categories (cascades to products if needed)
DELETE FROM public.categories;

-- Step 2: Insert all new categories
INSERT INTO public.categories (name, slug, item_count, image_url) VALUES

-- Main Shopping Categories
('Fashion',               'fashion',              0,  'https://images.unsplash.com/photo-1490481651871-ab68de25d43d?w=400'),
('Watches',               'watches',              0,  'https://images.unsplash.com/photo-1523275335684-37898b6baf30?w=400'),
('Beauty & Personal Care','beauty-personal-care', 0,  'https://images.unsplash.com/photo-1596462502278-27bfdc403348?w=400'),
('Electronics',           'electronics',          0,  'https://images.unsplash.com/photo-1498049794561-7780e7231661?w=400'),
('Home Decor',            'home-decor',           0,  'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=400'),
('Jewelry & Accessories', 'jewelry-accessories',  0,  'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=400'),
('Bags & Luggage',        'bags-luggage',         0,  'https://images.unsplash.com/photo-1548036328-c9fa89d128fa?w=400'),
('Footwear',              'footwear',             0,  'https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400'),
('Gifts & Luxury',        'gifts-luxury',         0,  'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?w=400'),
('Health & Wellness',     'health-wellness',      0,  'https://images.unsplash.com/photo-1571019613454-1cb2f99b2d8b?w=400'),
('Mobiles & Accessories', 'mobiles-accessories',  0,  'https://images.unsplash.com/photo-1511707171634-5f897ff02aa9?w=400');
