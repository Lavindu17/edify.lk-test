import React, { createContext, useContext, useReducer, ReactNode, useEffect } from 'react';
import { ArticleWithAuthor } from '../services/articleService';

interface AppState {
  articles: ArticleWithAuthor[];
  followedUsers: string[];
  likedArticles: string[];
  bookmarkedArticles: string[];
  notifications: any[];
  loading: boolean;
}

type AppAction =
  | { type: 'SET_ARTICLES'; payload: ArticleWithAuthor[] }
  | { type: 'ADD_ARTICLE'; payload: ArticleWithAuthor }
  | { type: 'UPDATE_ARTICLE'; payload: ArticleWithAuthor }
  | { type: 'REMOVE_ARTICLE'; payload: string }
  | { type: 'LIKE_ARTICLE'; payload: string }
  | { type: 'UNLIKE_ARTICLE'; payload: string }
  | { type: 'BOOKMARK_ARTICLE'; payload: string }
  | { type: 'UNBOOKMARK_ARTICLE'; payload: string }
  | { type: 'FOLLOW_USER'; payload: string }
  | { type: 'UNFOLLOW_USER'; payload: string }
  | { type: 'SET_LOADING'; payload: boolean };

const initialState: AppState = {
  articles: [],
  followedUsers: [],
  likedArticles: [],
  bookmarkedArticles: [],
  notifications: [],
  loading: false,
};

const appReducer = (state: AppState, action: AppAction): AppState => {
  switch (action.type) {
    case 'SET_ARTICLES':
      return { ...state, articles: action.payload };
    
    case 'ADD_ARTICLE':
      return { ...state, articles: [action.payload, ...state.articles] };
    
    case 'UPDATE_ARTICLE':
      return {
        ...state,
        articles: state.articles.map(article =>
          article.id === action.payload.id ? action.payload : article
        ),
      };
    
    case 'REMOVE_ARTICLE':
      return {
        ...state,
        articles: state.articles.filter(article => article.id !== action.payload),
      };
    
    case 'LIKE_ARTICLE':
      return {
        ...state,
        likedArticles: [...state.likedArticles, action.payload],
        articles: state.articles.map(article =>
          article.id === action.payload
            ? { ...article, likes_count: article.likes_count + 1, is_liked: true }
            : article
        ),
      };
    
    case 'UNLIKE_ARTICLE':
      return {
        ...state,
        likedArticles: state.likedArticles.filter(id => id !== action.payload),
        articles: state.articles.map(article =>
          article.id === action.payload
            ? { ...article, likes_count: Math.max(0, article.likes_count - 1), is_liked: false }
            : article
        ),
      };
    
    case 'BOOKMARK_ARTICLE':
      return {
        ...state,
        bookmarkedArticles: [...state.bookmarkedArticles, action.payload],
        articles: state.articles.map(article =>
          article.id === action.payload
            ? { ...article, is_bookmarked: true }
            : article
        ),
      };
    
    case 'UNBOOKMARK_ARTICLE':
      return {
        ...state,
        bookmarkedArticles: state.bookmarkedArticles.filter(id => id !== action.payload),
        articles: state.articles.map(article =>
          article.id === action.payload
            ? { ...article, is_bookmarked: false }
            : article
        ),
      };
    
    case 'FOLLOW_USER':
      return {
        ...state,
        followedUsers: [...state.followedUsers, action.payload],
      };
    
    case 'UNFOLLOW_USER':
      return {
        ...state,
        followedUsers: state.followedUsers.filter(id => id !== action.payload),
      };
    
    case 'SET_LOADING':
      return { ...state, loading: action.payload };
    
    default:
      return state;
  }
};

const AppContext = createContext<{
  state: AppState;
  dispatch: React.Dispatch<AppAction>;
} | null>(null);

export const useApp = () => {
  const context = useContext(AppContext);
  if (!context) {
    throw new Error('useApp must be used within an AppProvider');
  }
  return context;
};

export const AppProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
  const [state, dispatch] = useReducer(appReducer, initialState);

  return (
    <AppContext.Provider value={{ state, dispatch }}>
      {children}
    </AppContext.Provider>
  );
};