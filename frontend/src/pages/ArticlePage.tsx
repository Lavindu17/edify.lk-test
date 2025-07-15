import React, { useEffect, useState } from 'react';
import { useParams, Link, useNavigate } from 'react-router-dom';
import { motion } from 'framer-motion';
import SEOHead from '../components/seo/SEOHead';
import LazyImage from '../components/layout/LazyImage';
import { formatDistanceToNow } from 'date-fns';
import { 
  Heart, 
  MessageCircle, 
  Share2, 
  BookmarkPlus, 
  Clock, 
  Eye,
  Linkedin,
  Twitter,
  Facebook,
  Send
} from 'lucide-react';
import { useApp } from '../contexts/AppContext';
import { useAuth } from '../contexts/AuthContext';
import { articleService, ArticleWithAuthor } from '../services/articleService';
import LoadingSpinner from '../components/LoadingSpinner';
import QuizCard from '../components/quiz/QuizCard';
import BlockRenderer from '../components/write/BlockRenderer';

const ArticlePage: React.FC = () => {
  const { slug } = useParams<{ slug: string }>();
  const [article, setArticle] = useState<ArticleWithAuthor | null>(null);
  const [loading, setLoading] = useState(true);
  const [comment, setComment] = useState('');
  const [commentLoading, setCommentLoading] = useState(false);
  const { state, dispatch } = useApp();
  const { user } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    const fetchArticle = async () => {
      if (!slug) return;
      
      try {
        const fetchedArticle = await articleService.getArticleBySlug(slug, user?.id);
        if (fetchedArticle) {
          setArticle(fetchedArticle);
          // Update article in global state if it exists
          dispatch({ type: 'UPDATE_ARTICLE', payload: fetchedArticle });
        }
      } catch (error) {
        console.error('Failed to fetch article:', error);
      } finally {
        setLoading(false);
      }
    };

    fetchArticle();
  }, [slug, user?.id, dispatch]);

  const handleLike = async () => {
    if (!article || !user) return;
    
    try {
      if (article.is_liked) {
        await articleService.unlikeArticle(article.id, user.id);
        dispatch({ type: 'UNLIKE_ARTICLE', payload: article.id });
        setArticle(prev => prev ? { ...prev, is_liked: false, likes_count: prev.likes_count - 1 } : null);
      } else {
        await articleService.likeArticle(article.id, user.id);
        dispatch({ type: 'LIKE_ARTICLE', payload: article.id });
        setArticle(prev => prev ? { ...prev, is_liked: true, likes_count: prev.likes_count + 1 } : null);
      }
    } catch (error) {
      console.error('Error toggling like:', error);
    }
  };

  const handleBookmark = async () => {
    if (!article || !user) return;
    
    try {
      if (article.is_bookmarked) {
        await articleService.unbookmarkArticle(article.id, user.id);
        dispatch({ type: 'UNBOOKMARK_ARTICLE', payload: article.id });
        setArticle(prev => prev ? { ...prev, is_bookmarked: false } : null);
      } else {
        await articleService.bookmarkArticle(article.id, user.id);
        dispatch({ type: 'BOOKMARK_ARTICLE', payload: article.id });
        setArticle(prev => prev ? { ...prev, is_bookmarked: true } : null);
      }
    } catch (error) {
      console.error('Error toggling bookmark:', error);
    }
  };

  const shareUrl = `${window.location.origin}/article/${slug}`;

  if (loading) {
    return <LoadingSpinner />;
  }

  if (!article) {
    return (
      <div className="min-h-screen bg-dark-950 flex items-center justify-center">
        <div className="text-center">
          <h1 className="text-2xl font-bold text-white mb-4">Article Not Found</h1>
          <p className="text-gray-400 mb-8">The article you're looking for doesn't exist.</p>
          <Link 
            to="/"
            className="bg-primary-600 text-white px-6 py-3 rounded-lg hover:bg-primary-700 transition-colors"
          >
            Go Home
          </Link>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-dark-950">
      <SEOHead
        title={article.title}
        description={article.excerpt || ''}
        type="article"
        author={article.profiles.full_name || ''}
        publishedTime={article.published_at || ''}
        image={article.cover_image || ''}
        keywords={article.tags.map(tag => tag.name)}
        tags={article.tags.map(tag => tag.name)}
        section="Blog"
      />
      
      {/* Hero Section */}
      {article.cover_image && (
        <div className="relative h-96 overflow-hidden">
          <LazyImage
            src={article.cover_image}
            alt={article.title}
            className="w-full h-full object-cover"
          />
          <div className="absolute inset-0 bg-gradient-to-t from-dark-950 via-dark-950/50 to-transparent" />
        </div>
      )}

      <div className="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 -mt-32 relative z-10">
        <motion.article
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          className="bg-dark-900 border border-dark-800 rounded-xl p-8 shadow-2xl"
        >
          {/* Article Header */}
          <header className="mb-8">
            <div className="flex items-center space-x-2 mb-4">
              {article.tags.map(tag => (
                <span 
                  key={tag.id}
                  className="bg-primary-900/30 text-primary-300 px-3 py-1 rounded-full text-sm"
                  style={{ backgroundColor: tag.color ? `${tag.color}20` : undefined }}
                >
                  {tag.name}
                </span>
              ))}
            </div>
            
            <h1 className="text-3xl md:text-4xl font-bold text-white mb-6 leading-tight">
              {article.title}
            </h1>

            <div className="flex items-center justify-between flex-wrap gap-4">
              <div className="flex items-center space-x-4">
                <div className="flex items-center space-x-3">
                  <img
                    src={article.profiles.avatar_url || `https://ui-avatars.com/api/?name=${encodeURIComponent(article.profiles.full_name || 'User')}&background=AC834F&color=fff`}
                    alt={article.profiles.full_name || 'User'}
                    className="w-12 h-12 rounded-full"
                  />
                  <div>
                    <h3 className="font-medium text-white flex items-center space-x-2">
                      <span>{article.profiles.full_name}</span>
                      {article.profiles.is_verified && (
                        <span className="text-primary-500">✓</span>
                      )}
                    </h3>
                    <p className="text-sm text-gray-400">{article.profiles.followers_count.toLocaleString()} followers</p>
                  </div>
                </div>
                <div className="text-gray-400">
                  <div className="flex items-center space-x-4 text-sm">
                    <span>{formatDistanceToNow(new Date(article.published_at || article.created_at), { addSuffix: true })}</span>
                    <span>•</span>
                    <div className="flex items-center space-x-1">
                      <Clock className="w-4 h-4" />
                      <span>{article.reading_time} min read</span>
                    </div>
                    <span>•</span>
                    <div className="flex items-center space-x-1">
                      <Eye className="w-4 h-4" />
                      <span>{article.views_count} views</span>
                    </div>
                  </div>
                </div>
              </div>

              <div className="flex items-center space-x-2">
                <button
                  onClick={handleLike}
                  disabled={!user}
                  className={`flex items-center space-x-2 px-4 py-2 rounded-lg transition-colors ${
                    article.is_liked 
                      ? 'bg-red-500/20 text-red-400 border border-red-500/50' 
                      : 'bg-dark-800 text-gray-400 hover:text-red-400 border border-dark-700'
                  } ${!user ? 'opacity-50 cursor-not-allowed' : ''}`}
                >
                  <Heart className={`w-4 h-4 ${article.is_liked ? 'fill-current' : ''}`} />
                  <span>{article.likes_count}</span>
                </button>

                <div className="relative group">
                  <button className="flex items-center space-x-2 px-4 py-2 rounded-lg bg-dark-800 text-gray-400 hover:text-white border border-dark-700 transition-colors">
                    <Share2 className="w-4 h-4" />
                    <span>Share</span>
                  </button>
                  
                  <div className="absolute right-0 mt-2 w-48 bg-dark-800 rounded-lg shadow-lg border border-dark-700 py-2 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none group-hover:pointer-events-auto">
                    <a
                      href={`https://www.linkedin.com/sharing/share-offsite/?url=${encodeURIComponent(shareUrl)}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center space-x-2 px-4 py-2 text-gray-300 hover:text-white hover:bg-dark-700 transition-colors"
                    >
                      <Linkedin className="w-4 h-4" />
                      <span>LinkedIn</span>
                    </a>
                    <a
                      href={`https://twitter.com/intent/tweet?url=${encodeURIComponent(shareUrl)}&text=${encodeURIComponent(article.title)}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center space-x-2 px-4 py-2 text-gray-300 hover:text-white hover:bg-dark-700 transition-colors"
                    >
                      <Twitter className="w-4 h-4" />
                      <span>Twitter</span>
                    </a>
                    <a
                      href={`https://www.facebook.com/sharer/sharer.php?u=${encodeURIComponent(shareUrl)}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="flex items-center space-x-2 px-4 py-2 text-gray-300 hover:text-white hover:bg-dark-700 transition-colors"
                    >
                      <Facebook className="w-4 h-4" />
                      <span>Facebook</span>
                    </a>
                  </div>
                </div>

                <button 
                  onClick={handleBookmark}
                  disabled={!user}
                  className={`p-2 rounded-lg border border-dark-700 transition-colors ${
                    article.is_bookmarked 
                      ? 'bg-primary-900/30 text-primary-400 border-primary-500/50' 
                      : 'bg-dark-800 text-gray-400 hover:text-primary-400'
                  } ${!user ? 'opacity-50 cursor-not-allowed' : ''}`}
                >
                  <BookmarkPlus className={`w-4 h-4 ${article.is_bookmarked ? 'fill-current' : ''}`} />
                </button>
              </div>
            </div>
          </header>

          {/* Article Content */}
          <div className="mb-12">
            <BlockRenderer blocks={article.content} />
          </div>

          {/* Quiz Section */}
          <QuizCard articleId={article.id} />
        </motion.article>
      </div>
    </div>
  );
};

export default ArticlePage;