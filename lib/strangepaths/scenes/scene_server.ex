defmodule Strangepaths.Scenes.SceneServer do
  @moduledoc """
  GenServer for managing real-time scene state and broadcasting updates.
  Caches recent posts in memory and broadcasts via PubSub.
  """

  use GenServer
  require Logger

  alias Strangepaths.Scenes
  alias StrangepathsWeb.Endpoint

  @posts_cache_limit 30

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Broadcasts a new post to all subscribers of a scene.
  """
  def broadcast_post(scene_id, post) do
    GenServer.cast(__MODULE__, {:broadcast_post, scene_id, post})
  end

  @doc """
  Broadcasts scene list update (new scene created, scene archived, etc.).
  """
  def broadcast_scene_update do
    GenServer.cast(__MODULE__, :broadcast_scene_update)
  end

  @doc """
  Gets cached posts for a scene (last 30 posts).
  """
  def get_cached_posts(scene_id) do
    GenServer.call(__MODULE__, {:get_cached_posts, scene_id})
  end

  @doc """
  Invalidates the cache for a scene (forces reload from DB next time).
  """
  def invalidate_cache(scene_id) do
    GenServer.cast(__MODULE__, {:invalidate_cache, scene_id})
  end

  # Server Callbacks

  @impl true
  def init(_) do
    Logger.info("Starting SceneServer...")
    # Ensure Elsewhere scene exists on startup
    case Scenes.ensure_elsewhere_scene() do
      {:ok, scene} ->
        Logger.info("Elsewhere scene ready: #{scene.name} (ID: #{scene.id})")
      {:error, reason} ->
        Logger.error("Failed to ensure Elsewhere scene: #{inspect(reason)}")
    end

    {:ok, %{cache: %{}}}
  end

  @impl true
  def handle_call({:get_cached_posts, scene_id}, _from, state) do
    posts = case Map.get(state.cache, scene_id) do
      nil ->
        # Load from database and cache
        posts = Scenes.list_posts(scene_id, @posts_cache_limit)
        {:reply, posts, put_in(state, [:cache, scene_id], posts)}

      cached_posts ->
        {:reply, cached_posts, state}
    end

    case posts do
      {:reply, posts, new_state} -> {:reply, posts, new_state}
      _ -> {:reply, [], state}
    end
  end

  @impl true
  def handle_cast({:broadcast_post, scene_id, post}, state) do
    # Broadcast the new post to all scene subscribers
    Endpoint.broadcast("scene:#{scene_id}", "new_post", %{
      post: post,
      user: post.user,
      avatar: post.avatar
    })

    # Update cache: add post to front, trim to limit
    new_cache = case Map.get(state.cache, scene_id) do
      nil ->
        # Not cached yet, load it
        posts = Scenes.list_posts(scene_id, @posts_cache_limit)
        Map.put(state.cache, scene_id, posts)

      cached_posts ->
        updated_posts = [post | cached_posts]
        |> Enum.take(@posts_cache_limit)
        Map.put(state.cache, scene_id, updated_posts)
    end

    {:noreply, %{state | cache: new_cache}}
  end

  @impl true
  def handle_cast(:broadcast_scene_update, state) do
    # Broadcast to the lobby that the scene list has changed
    Endpoint.broadcast("scenes:lobby", "scene_list_updated", %{})
    {:noreply, state}
  end

  @impl true
  def handle_cast({:invalidate_cache, scene_id}, state) do
    new_cache = Map.delete(state.cache, scene_id)
    {:noreply, %{state | cache: new_cache}}
  end
end
