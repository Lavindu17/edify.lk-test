/*
  # Complete Edify Database Schema

  1. New Tables
    - `profiles` - User profiles with extended information
    - `articles` - Blog articles with rich content
    - `tags` - Article categorization tags  
    - `article_tags` - Many-to-many relationship between articles and tags
    - `comments` - Article comments with threading support
    - `likes` - Likes for articles and comments
    - `follows` - User following relationships
    - `bookmarks` - User bookmarks for articles
    - `notifications` - User notification system

  2. Security
    - Enable RLS on all tables
    - Add policies for authenticated users
    - Secure user data access

  3. Functions and Triggers
    - Auto-update counters
    - Profile creation on signup
*/

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text,
  avatar_url text,
  bio text,
  website text,
  location text,
  twitter_handle text,
  linkedin_url text,
  github_url text,
  is_verified boolean DEFAULT false,
  role text DEFAULT 'user' CHECK (role IN ('user', 'admin', 'moderator')),
  followers_count integer DEFAULT 0,
  following_count integer DEFAULT 0,
  articles_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create tags table
CREATE TABLE IF NOT EXISTS tags (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  name text UNIQUE NOT NULL,
  slug text UNIQUE NOT NULL,
  description text,
  color text,
  articles_count integer DEFAULT 0,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create articles table
CREATE TABLE IF NOT EXISTS articles (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  title text NOT NULL,
  slug text UNIQUE NOT NULL,
  content jsonb NOT NULL DEFAULT '[]',
  excerpt text,
  cover_image text,
  author_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  status text DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
  featured boolean DEFAULT false,
  reading_time integer DEFAULT 1,
  views_count integer DEFAULT 0,
  likes_count integer DEFAULT 0,
  comments_count integer DEFAULT 0,
  published_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create article_tags junction table
CREATE TABLE IF NOT EXISTS article_tags (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  article_id uuid REFERENCES articles(id) ON DELETE CASCADE NOT NULL,
  tag_id uuid REFERENCES tags(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(article_id, tag_id)
);

-- Create comments table
CREATE TABLE IF NOT EXISTS comments (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  content text NOT NULL,
  article_id uuid REFERENCES articles(id) ON DELETE CASCADE NOT NULL,
  author_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  parent_id uuid REFERENCES comments(id) ON DELETE CASCADE,
  likes_count integer DEFAULT 0,
  is_edited boolean DEFAULT false,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create likes table
CREATE TABLE IF NOT EXISTS likes (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  article_id uuid REFERENCES articles(id) ON DELETE CASCADE,
  comment_id uuid REFERENCES comments(id) ON DELETE CASCADE,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, article_id),
  UNIQUE(user_id, comment_id),
  CHECK ((article_id IS NOT NULL AND comment_id IS NULL) OR (article_id IS NULL AND comment_id IS NOT NULL))
);

-- Create follows table
CREATE TABLE IF NOT EXISTS follows (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  follower_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  following_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(follower_id, following_id),
  CHECK (follower_id != following_id)
);

-- Create bookmarks table
CREATE TABLE IF NOT EXISTS bookmarks (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  article_id uuid REFERENCES articles(id) ON DELETE CASCADE NOT NULL,
  created_at timestamptz DEFAULT now(),
  UNIQUE(user_id, article_id)
);

-- Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id uuid PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  type text NOT NULL CHECK (type IN ('like', 'comment', 'follow', 'article_published', 'mention')),
  title text NOT NULL,
  message text NOT NULL,
  data jsonb,
  read boolean DEFAULT false,
  created_at timestamptz DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE articles ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE article_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE follows ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can view all profiles" ON profiles FOR SELECT USING (true);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Users can insert own profile" ON profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- Articles policies
CREATE POLICY "Anyone can view published articles" ON articles FOR SELECT USING (status = 'published' OR author_id = auth.uid());
CREATE POLICY "Authors can manage own articles" ON articles FOR ALL USING (author_id = auth.uid());

-- Tags policies
CREATE POLICY "Anyone can view tags" ON tags FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create tags" ON tags FOR INSERT TO authenticated WITH CHECK (true);

-- Article tags policies
CREATE POLICY "Anyone can view article tags" ON article_tags FOR SELECT USING (true);
CREATE POLICY "Authors can manage article tags" ON article_tags FOR ALL USING (
  EXISTS (SELECT 1 FROM articles WHERE articles.id = article_tags.article_id AND articles.author_id = auth.uid())
);

-- Comments policies
CREATE POLICY "Anyone can view comments" ON comments FOR SELECT USING (true);
CREATE POLICY "Authenticated users can create comments" ON comments FOR INSERT TO authenticated WITH CHECK (author_id = auth.uid());
CREATE POLICY "Authors can update own comments" ON comments FOR UPDATE USING (author_id = auth.uid());
CREATE POLICY "Authors can delete own comments" ON comments FOR DELETE USING (author_id = auth.uid());

-- Likes policies
CREATE POLICY "Anyone can view likes" ON likes FOR SELECT USING (true);
CREATE POLICY "Authenticated users can manage own likes" ON likes FOR ALL USING (user_id = auth.uid());

-- Follows policies
CREATE POLICY "Anyone can view follows" ON follows FOR SELECT USING (true);
CREATE POLICY "Authenticated users can manage own follows" ON follows FOR ALL USING (follower_id = auth.uid());

-- Bookmarks policies
CREATE POLICY "Users can view own bookmarks" ON bookmarks FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can manage own bookmarks" ON bookmarks FOR ALL USING (user_id = auth.uid());

-- Notifications policies
CREATE POLICY "Users can view own notifications" ON notifications FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE USING (user_id = auth.uid());

-- Functions to update counters
CREATE OR REPLACE FUNCTION update_article_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Update likes count
    IF NEW.article_id IS NOT NULL THEN
      UPDATE articles SET likes_count = likes_count + 1 WHERE id = NEW.article_id;
    END IF;
    -- Update comments count
    IF TG_TABLE_NAME = 'comments' THEN
      UPDATE articles SET comments_count = comments_count + 1 WHERE id = NEW.article_id;
    END IF;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    -- Update likes count
    IF OLD.article_id IS NOT NULL THEN
      UPDATE articles SET likes_count = likes_count - 1 WHERE id = OLD.article_id;
    END IF;
    -- Update comments count
    IF TG_TABLE_NAME = 'comments' THEN
      UPDATE articles SET comments_count = comments_count - 1 WHERE id = OLD.article_id;
    END IF;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers
CREATE TRIGGER update_likes_count
  AFTER INSERT OR DELETE ON likes
  FOR EACH ROW EXECUTE FUNCTION update_article_counts();

CREATE TRIGGER update_comments_count
  AFTER INSERT OR DELETE ON comments
  FOR EACH ROW EXECUTE FUNCTION update_article_counts();

-- Function to create profile on signup
CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email),
    COALESCE(NEW.raw_user_meta_data->>'avatar_url', '')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger for new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

-- Insert sample data
INSERT INTO profiles (id, email, full_name, avatar_url, bio, is_verified, followers_count, articles_count) VALUES
  ('550e8400-e29b-41d4-a716-446655440001', 'lavindu@example.com', 'Lavindu Binuwara', 'https://media.licdn.com/dms/image/v2/D5603AQGgIlxEuk7sDw/profile-displayphoto-shrink_100_100/B56ZXXQS69GcAU-/0/1743073128704?e=1756944000&v=beta&t=Mbkn0HPtM2WmEt9WAWgN5RBPFPKb0ACjgwjUkeJPetk', 'AI researcher and technology strategist with 15 years of experience in machine learning and neural networks.', true, 12500, 47),
  ('550e8400-e29b-41d4-a716-446655440002', 'hashani@example.com', 'Hashani Uduwage', 'https://media.licdn.com/dms/image/v2/D4E03AQFM2bia86LEpQ/profile-displayphoto-shrink_100_100/B4EZQ1W9ILHEAU-/0/1736062004138?e=1756944000&v=beta&t=NRca3iZVIMWnDQX4DSCf3jjF73JgMJJkV_QeUUxxPiY', 'Sustainability consultant and business strategist helping organizations build responsible and profitable business models.', false, 8900, 32),
  ('550e8400-e29b-41d4-a716-446655440003', 'buddhika@example.com', 'Buddhika Bandara', 'https://media.licdn.com/dms/image/v2/D5603AQGTXKzL1LlvBA/profile-displayphoto-shrink_800_800/B56ZVREf3oHQAc-/0/1740821889504?e=1756944000&v=beta&t=-Vj2WYcdaURintD3LbYDj3F8PppAhscNTYfcdvJZVfk', 'Workplace transformation expert and organizational psychologist focused on the future of work.', true, 15200, 28)
ON CONFLICT (id) DO NOTHING;

-- Insert sample tags
INSERT INTO tags (id, name, slug, description, color) VALUES
  ('650e8400-e29b-41d4-a716-446655440001', 'AI', 'ai', 'Artificial Intelligence and Machine Learning', '#3B82F6'),
  ('650e8400-e29b-41d4-a716-446655440002', 'Technology', 'technology', 'Latest technology trends and innovations', '#10B981'),
  ('650e8400-e29b-41d4-a716-446655440003', 'Future', 'future', 'Future predictions and trends', '#8B5CF6'),
  ('650e8400-e29b-41d4-a716-446655440004', 'Innovation', 'innovation', 'Innovation in various fields', '#F59E0B'),
  ('650e8400-e29b-41d4-a716-446655440005', 'Sustainability', 'sustainability', 'Environmental and business sustainability', '#059669'),
  ('650e8400-e29b-41d4-a716-446655440006', 'Business', 'business', 'Business strategies and insights', '#DC2626'),
  ('650e8400-e29b-41d4-a716-446655440007', 'Remote Work', 'remote-work', 'Remote work trends and best practices', '#7C3AED'),
  ('650e8400-e29b-41d4-a716-446655440008', 'Workplace', 'workplace', 'Modern workplace transformation', '#059669')
ON CONFLICT (id) DO NOTHING;

-- Insert sample articles
INSERT INTO articles (id, title, slug, content, excerpt, cover_image, author_id, status, featured, reading_time, views_count, likes_count, published_at) VALUES
  (
    '750e8400-e29b-41d4-a716-446655440001',
    'The Future of Artificial Intelligence: Transforming Industries and Society',
    'future-of-artificial-intelligence',
    '[
      {"type": "paragraph", "children": [{"text": "Artificial Intelligence is no longer a concept confined to science fiction novels or futuristic films. It has become an integral part of our daily lives, reshaping industries and redefining what''s possible in the digital age."}]},
      {"type": "heading", "level": 2, "children": [{"text": "The Dawn of a New Era"}]},
      {"type": "paragraph", "children": [{"text": "From healthcare to finance, from manufacturing to entertainment, AI is creating unprecedented opportunities for innovation and efficiency. Machine learning algorithms are now capable of diagnosing diseases with remarkable accuracy, autonomous vehicles are becoming a reality, and personalized recommendations are enhancing user experiences across platforms."}]},
      {"type": "heading", "level": 3, "children": [{"text": "Industry Transformation"}]},
      {"type": "paragraph", "children": [{"text": "While AI continues to advance, the human touch remains irreplaceable. The most successful AI implementations are those that augment human capabilities rather than replace them entirely. This symbiotic relationship between human creativity and artificial intelligence opens new frontiers for innovation."}]},
      {"type": "heading", "level": 3, "children": [{"text": "The Human Element"}]},
      {"type": "paragraph", "children": [{"text": "As we stand on the cusp of this technological revolution, it''s crucial to approach AI development with both excitement and responsibility. The decisions we make today will shape the AI landscape of tomorrow, influencing how technology serves humanity''s best interests."}]}
    ]',
    'Explore how AI is revolutionizing various sectors and what it means for the future of work, creativity, and human interaction.',
    'https://images.pexels.com/photos/8386440/pexels-photo-8386440.jpeg?auto=compress&cs=tinysrgb&w=800&h=400&dpr=1',
    '550e8400-e29b-41d4-a716-446655440001',
    'published',
    true,
    8,
    1250,
    234,
    '2024-01-15T10:30:00Z'
  ),
  (
    '750e8400-e29b-41d4-a716-446655440002',
    'Sustainable Business Practices: A Guide to Corporate Responsibility',
    'sustainable-business-practices',
    '[
      {"type": "paragraph", "children": [{"text": "In today''s rapidly evolving business landscape, sustainability has moved from a nice-to-have to a must-have. Companies that fail to adopt sustainable practices risk not only environmental impact but also their competitive edge and stakeholder trust."}]},
      {"type": "heading", "level": 2, "children": [{"text": "The Imperative of Sustainable Business"}]},
      {"type": "paragraph", "children": [{"text": "Leading organizations are implementing comprehensive environmental strategies that go beyond compliance. From reducing carbon footprints to embracing circular economy principles, businesses are finding innovative ways to minimize their environmental impact while maximizing operational efficiency."}]},
      {"type": "heading", "level": 3, "children": [{"text": "Environmental Stewardship"}]},
      {"type": "paragraph", "children": [{"text": "Sustainable business practices extend beyond environmental concerns to encompass social responsibility. This includes fair labor practices, community engagement, and creating positive social impact through business operations."}]},
      {"type": "heading", "level": 3, "children": [{"text": "Social Responsibility"}]},
      {"type": "paragraph", "children": [{"text": "The most successful sustainable business models demonstrate that environmental and social responsibility can coexist with profitability. Companies that embrace this triple bottom line approach often discover new revenue streams and cost savings opportunities."}]}
    ]',
    'Discover how modern businesses are integrating sustainability into their core operations and why it matters for long-term success.',
    'https://images.pexels.com/photos/1108572/pexels-photo-1108572.jpeg?auto=compress&cs=tinysrgb&w=800&h=400&dpr=1',
    '550e8400-e29b-41d4-a716-446655440002',
    'published',
    false,
    6,
    890,
    187,
    '2024-01-12T09:15:00Z'
  ),
  (
    '750e8400-e29b-41d4-a716-446655440003',
    'The Rise of Remote Work: Reshaping the Modern Workplace',
    'rise-of-remote-work',
    '[
      {"type": "paragraph", "children": [{"text": "The global shift toward remote work has fundamentally changed how we think about productivity, collaboration, and work-life balance. What started as a necessity has evolved into a preferred working model for many organizations and employees."}]},
      {"type": "heading", "level": 2, "children": [{"text": "A Paradigm Shift in Work Culture"}]},
      {"type": "paragraph", "children": [{"text": "Advanced communication tools, cloud computing, and collaborative platforms have made remote work not just possible but highly effective. Organizations are discovering that with the right technology stack, distributed teams can be just as productive as their in-office counterparts."}]},
      {"type": "heading", "level": 3, "children": [{"text": "Technology as the Great Enabler"}]},
      {"type": "paragraph", "children": [{"text": "While remote work offers numerous benefits, it also presents unique challenges. Maintaining team cohesion, ensuring effective communication, and preventing isolation are ongoing concerns that organizations must address thoughtfully."}]},
      {"type": "heading", "level": 3, "children": [{"text": "Challenges and Opportunities"}]},
      {"type": "paragraph", "children": [{"text": "As we look ahead, the future of work will likely be hybrid, combining the best of both remote and in-person collaboration. Organizations that adapt to this new reality will be better positioned to attract and retain top talent."}]}
    ]',
    'An in-depth look at how remote work is transforming organizational culture, productivity, and the future of employment.',
    'https://images.pexels.com/photos/4164418/pexels-photo-4164418.jpeg?auto=compress&cs=tinysrgb&w=800&h=400&dpr=1',
    '550e8400-e29b-41d4-a716-446655440003',
    'published',
    true,
    7,
    1100,
    312,
    '2024-01-10T16:45:00Z'
  )
ON CONFLICT (id) DO NOTHING;

-- Insert article-tag relationships
INSERT INTO article_tags (article_id, tag_id) VALUES
  ('750e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440001'), -- AI article -> AI tag
  ('750e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440002'), -- AI article -> Technology tag
  ('750e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440003'), -- AI article -> Future tag
  ('750e8400-e29b-41d4-a716-446655440001', '650e8400-e29b-41d4-a716-446655440004'), -- AI article -> Innovation tag
  ('750e8400-e29b-41d4-a716-446655440002', '650e8400-e29b-41d4-a716-446655440005'), -- Sustainability article -> Sustainability tag
  ('750e8400-e29b-41d4-a716-446655440002', '650e8400-e29b-41d4-a716-446655440006'), -- Sustainability article -> Business tag
  ('750e8400-e29b-41d4-a716-446655440003', '650e8400-e29b-41d4-a716-446655440007'), -- Remote Work article -> Remote Work tag
  ('750e8400-e29b-41d4-a716-446655440003', '650e8400-e29b-41d4-a716-446655440008')  -- Remote Work article -> Workplace tag
ON CONFLICT (article_id, tag_id) DO NOTHING;

-- Insert sample comments
INSERT INTO comments (id, content, article_id, author_id, likes_count, created_at) VALUES
  (
    '850e8400-e29b-41d4-a716-446655440001',
    'This is a fascinating perspective on AI development. I particularly appreciate the emphasis on human-AI collaboration rather than replacement.',
    '750e8400-e29b-41d4-a716-446655440001',
    '550e8400-e29b-41d4-a716-446655440002',
    12,
    '2024-01-15T14:22:00Z'
  ),
  (
    '850e8400-e29b-41d4-a716-446655440002',
    'Great insights on sustainability! More companies need to understand that sustainable practices can actually improve their bottom line.',
    '750e8400-e29b-41d4-a716-446655440002',
    '550e8400-e29b-41d4-a716-446655440003',
    8,
    '2024-01-12T16:30:00Z'
  )
ON CONFLICT (id) DO NOTHING;