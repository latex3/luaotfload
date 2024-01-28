-- Helper to resolve symlinks in paths

local sub = string.sub
local symlinkattributes = lfs.symlinkattributes
local currentdir = lfs.currentdir
local concat = table.concat
local move = table.move
local newtable = lua.newtable
local setmetatable = setmetatable

-- Marker key for elements of result_tree to indicate the path components entry and the file mode
local path_components, file_mode = {}, {}
local tree_root

local split_path do
  local l = lpeg
  local separator = l.S'/'
  -- We do not allow empty segments here because they get ignored.
  local segment = l.C((1 - separator)^1)
  -- Duplicate and trailing separators are dropped.
  local path_pat = l.Ct((l.Cc'' * separator^1)^-1 * (segment * separator^1)^0 * segment^-1 * -1)
  function split_path(path)
    return assert(path_pat:match(path))
  end
end

local function lookup_split_path_in_tree(components, tree)
  if components[1] == '' then
    tree = tree_root
  end
  for i=1, #components do
    local next_tree = tree[components[i]]
    if not next_tree then
      return nil, string.format("Unable to find %q in %q", components[i], concat(tree[path_components], '/'))
    end
    tree = next_tree
  end
  return tree
end

local tree_meta
tree_meta = {
  __index = function(parent, component)
    local parent_components = parent[path_components]
    local depth = #parent_components
    local components = move(parent[path_components], 1, depth, 1, newtable(depth + 1, 0))
    components[depth + 1] = component
    local path = concat(components, '/')

    local mode = symlinkattributes(path, 'mode')
    if not mode then
      parent[component] = false
      return false
    end
    if mode == 'link' then
      local target = symlinkattributes(path, 'target')
      local splitted_target = split_path(target)
      local target_tree = lookup_split_path_in_tree(splitted_target, parent) or false
      parent[component] = target_tree
      return target_tree
    end

    local child = {
      [path_components] = components,
      [file_mode] = mode,
    }
    if mode == 'directory' then
      setmetatable(child, tree_meta)
      child['.'] = child
      child['..'] = parent
    end
    parent[component] = child
    return child
  end,
}

-- We assume that the directory structure does not change during our run.
tree_root = {
  [''] = setmetatable({
    [path_components] = {''},
    [file_mode] = 'directory', -- "If [your root is not a directory] you are having a bad problem and you will not go to space today".
  }, tree_meta)
}
do
  local root_dir = tree_root['']
  root_dir['.'] = root_dir
  root_dir['..'] = root_dir
end

local function resolve_path_to_tree(path)
  local splitted = split_path(path)
  if splitted[1] == '' then -- Optimization to avoid currentdir lookup.
    return lookup_split_path_in_tree(splitted, tree_root)
  else
    local splitted_currentdir = split_path(currentdir())
    local current_tree = assert(lookup_split_path_in_tree(splitted_currentdir, tree_root))
    return lookup_split_path_in_tree(splitted, current_tree)
  end
end

local function resolve_path(path)
  local tree, err = resolve_path_to_tree(path)
  if not tree then return tree, err end
  return concat(tree[path_components], '/'), tree[file_mode]
end

return {
  realpath = resolve_path,
}
