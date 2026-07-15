"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode
} from "react";
import {
  apiCreateContentStory,
  apiCreateNewsPost,
  apiCreateStoryCollection,
  apiDeleteCollectionCover,
  apiDeleteContentStory,
  apiDeleteNewsPost,
  apiDeleteNewsPostMedia,
  apiDeleteStoryCollection,
  apiDeleteStoryMedia,
  apiFetchContentStories,
  apiFetchNewsPosts,
  apiFetchStoryCollections,
  apiPatchContentStory,
  apiPatchNewsPost,
  apiPatchStoryCollection,
  apiUploadCollectionCover,
  apiUploadNewsPostMedia,
  apiUploadStoryMedia,
  describeApiError,
  type ContentStoryWrite,
  type NewsPostWrite,
  type StoryCollectionWrite
} from "@/lib/api";
import type { ContentStory, NewsPost, StoryCollection } from "@/lib/types";

export type ContentLoadStatus = "loading" | "ready" | "error";

export interface ContentResource<T> {
  status: ContentLoadStatus;
  items: T[];
  error: string | null;
}

interface ContentManagerValue {
  stories: ContentResource<ContentStory>;
  collections: ContentResource<StoryCollection>;
  posts: ContentResource<NewsPost>;
  reloadStories: () => Promise<void>;
  reloadCollections: () => Promise<void>;
  reloadPosts: () => Promise<void>;
  saveStory: (id: string | null, value: ContentStoryWrite) => Promise<ContentStory>;
  deleteStory: (id: string) => Promise<void>;
  uploadStoryMedia: (id: string, file: File) => Promise<ContentStory>;
  removeStoryMedia: (id: string) => Promise<ContentStory>;
  saveCollection: (
    id: string | null,
    value: StoryCollectionWrite
  ) => Promise<StoryCollection>;
  deleteCollection: (id: string) => Promise<void>;
  uploadCollectionCover: (id: string, file: File) => Promise<StoryCollection>;
  removeCollectionCover: (id: string) => Promise<StoryCollection>;
  savePost: (id: string | null, value: NewsPostWrite) => Promise<NewsPost>;
  deletePost: (id: string) => Promise<void>;
  uploadPostMedia: (id: string, file: File) => Promise<NewsPost>;
  removePostMedia: (id: string) => Promise<NewsPost>;
}

const ContentManagerContext = createContext<ContentManagerValue | null>(null);

const loading = <T,>(): ContentResource<T> => ({
  status: "loading",
  items: [],
  error: null
});

const byStoryOrder = (a: ContentStory, b: ContentStory) =>
  Number(b.isPinned) - Number(a.isPinned) ||
  Date.parse(b.publishedAt) - Date.parse(a.publishedAt) ||
  a.sortOrder - b.sortOrder ||
  a.id.localeCompare(b.id);

const byCollectionOrder = (a: StoryCollection, b: StoryCollection) =>
  a.sortOrder - b.sortOrder || a.id.localeCompare(b.id);

const byPostDate = (a: NewsPost, b: NewsPost) =>
  Date.parse(b.publishedAt) - Date.parse(a.publishedAt) ||
  a.id.localeCompare(b.id);

function replaceById<T extends { id: string }>(items: T[], value: T): T[] {
  const index = items.findIndex((item) => item.id === value.id);
  if (index < 0) return [...items, value];
  return items.map((item) => (item.id === value.id ? value : item));
}

export function ContentManagerProvider({
  companyId,
  children
}: {
  companyId: string;
  children: ReactNode;
}) {
  const [stories, setStories] = useState<ContentResource<ContentStory>>(loading);
  const [collections, setCollections] =
    useState<ContentResource<StoryCollection>>(loading);
  const [posts, setPosts] = useState<ContentResource<NewsPost>>(loading);

  const reloadStories = useCallback(async () => {
    setStories((current) => ({ ...current, status: "loading", error: null }));
    try {
      const items = (await apiFetchContentStories(companyId)).sort(byStoryOrder);
      setStories({ status: "ready", items, error: null });
    } catch (error) {
      setStories((current) => ({
        ...current,
        status: "error",
        error: describeApiError(error)
      }));
    }
  }, [companyId]);

  const reloadCollections = useCallback(async () => {
    setCollections((current) => ({
      ...current,
      status: "loading",
      error: null
    }));
    try {
      const items = (await apiFetchStoryCollections(companyId)).sort(
        byCollectionOrder
      );
      setCollections({ status: "ready", items, error: null });
    } catch (error) {
      setCollections((current) => ({
        ...current,
        status: "error",
        error: describeApiError(error)
      }));
    }
  }, [companyId]);

  const reloadPosts = useCallback(async () => {
    setPosts((current) => ({ ...current, status: "loading", error: null }));
    try {
      const items = (await apiFetchNewsPosts(companyId)).sort(byPostDate);
      setPosts({ status: "ready", items, error: null });
    } catch (error) {
      setPosts((current) => ({
        ...current,
        status: "error",
        error: describeApiError(error)
      }));
    }
  }, [companyId]);

  useEffect(() => {
    void reloadStories();
    void reloadCollections();
    void reloadPosts();
  }, [reloadStories, reloadCollections, reloadPosts]);

  const saveStory = useCallback(
    async (id: string | null, value: ContentStoryWrite) => {
      const saved = id
        ? await apiPatchContentStory(companyId, id, value)
        : await apiCreateContentStory(companyId, value);
      setStories((current) => ({
        status: "ready",
        error: null,
        items: replaceById(current.items, saved).sort(byStoryOrder)
      }));
      void reloadCollections();
      return saved;
    },
    [companyId, reloadCollections]
  );

  const deleteStory = useCallback(
    async (id: string) => {
      await apiDeleteContentStory(companyId, id);
      setStories((current) => ({
        ...current,
        items: current.items.filter((item) => item.id !== id)
      }));
      void reloadCollections();
    },
    [companyId, reloadCollections]
  );

  const uploadStoryMedia = useCallback(
    async (id: string, file: File) => {
      const saved = await apiUploadStoryMedia(companyId, id, file);
      setStories((current) => ({
        ...current,
        items: replaceById(current.items, saved).sort(byStoryOrder)
      }));
      return saved;
    },
    [companyId]
  );

  const removeStoryMedia = useCallback(
    async (id: string) => {
      const saved = await apiDeleteStoryMedia(companyId, id);
      setStories((current) => ({
        ...current,
        items: replaceById(current.items, saved).sort(byStoryOrder)
      }));
      return saved;
    },
    [companyId]
  );

  const saveCollection = useCallback(
    async (id: string | null, value: StoryCollectionWrite) => {
      const saved = id
        ? await apiPatchStoryCollection(companyId, id, value)
        : await apiCreateStoryCollection(companyId, value);
      setCollections((current) => ({
        status: "ready",
        error: null,
        items: replaceById(current.items, saved).sort(byCollectionOrder)
      }));
      return saved;
    },
    [companyId]
  );

  const deleteCollection = useCallback(
    async (id: string) => {
      await apiDeleteStoryCollection(companyId, id);
      setCollections((current) => ({
        ...current,
        items: current.items.filter((item) => item.id !== id)
      }));
      // The backend is authoritative about whether nested stories are detached
      // or removed together with the collection.
      void reloadStories();
    },
    [companyId, reloadStories]
  );

  const uploadCollectionCover = useCallback(
    async (id: string, file: File) => {
      const saved = await apiUploadCollectionCover(companyId, id, file);
      setCollections((current) => ({
        ...current,
        items: replaceById(current.items, saved).sort(byCollectionOrder)
      }));
      return saved;
    },
    [companyId]
  );

  const removeCollectionCover = useCallback(
    async (id: string) => {
      const saved = await apiDeleteCollectionCover(companyId, id);
      setCollections((current) => ({
        ...current,
        items: replaceById(current.items, saved).sort(byCollectionOrder)
      }));
      return saved;
    },
    [companyId]
  );

  const savePost = useCallback(
    async (id: string | null, value: NewsPostWrite) => {
      const saved = id
        ? await apiPatchNewsPost(companyId, id, value)
        : await apiCreateNewsPost(companyId, value);
      setPosts((current) => ({
        status: "ready",
        error: null,
        items: replaceById(current.items, saved).sort(byPostDate)
      }));
      return saved;
    },
    [companyId]
  );

  const deletePost = useCallback(
    async (id: string) => {
      await apiDeleteNewsPost(companyId, id);
      setPosts((current) => ({
        ...current,
        items: current.items.filter((item) => item.id !== id)
      }));
    },
    [companyId]
  );

  const uploadPostMedia = useCallback(
    async (id: string, file: File) => {
      const saved = await apiUploadNewsPostMedia(companyId, id, file);
      setPosts((current) => ({
        ...current,
        items: replaceById(current.items, saved).sort(byPostDate)
      }));
      return saved;
    },
    [companyId]
  );

  const removePostMedia = useCallback(
    async (id: string) => {
      const saved = await apiDeleteNewsPostMedia(companyId, id);
      setPosts((current) => ({
        ...current,
        items: replaceById(current.items, saved).sort(byPostDate)
      }));
      return saved;
    },
    [companyId]
  );

  const value = useMemo<ContentManagerValue>(
    () => ({
      stories,
      collections,
      posts,
      reloadStories,
      reloadCollections,
      reloadPosts,
      saveStory,
      deleteStory,
      uploadStoryMedia,
      removeStoryMedia,
      saveCollection,
      deleteCollection,
      uploadCollectionCover,
      removeCollectionCover,
      savePost,
      deletePost,
      uploadPostMedia,
      removePostMedia
    }),
    [
      stories,
      collections,
      posts,
      reloadStories,
      reloadCollections,
      reloadPosts,
      saveStory,
      deleteStory,
      uploadStoryMedia,
      removeStoryMedia,
      saveCollection,
      deleteCollection,
      uploadCollectionCover,
      removeCollectionCover,
      savePost,
      deletePost,
      uploadPostMedia,
      removePostMedia
    ]
  );

  return (
    <ContentManagerContext.Provider value={value}>
      {children}
    </ContentManagerContext.Provider>
  );
}

export function useContentManager(): ContentManagerValue {
  const value = useContext(ContentManagerContext);
  if (!value) {
    throw new Error("useContentManager must be used inside ContentManagerProvider");
  }
  return value;
}
