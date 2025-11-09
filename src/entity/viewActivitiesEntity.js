export function activityEntity(rawData) {
  const { title, summary, category, difficulty, duration, image, description, requiresAuth, tags } = rawData;

  function validate() {
    if (!title || !title.trim()) return "Title is required.";
    if (!summary || !summary.trim()) return "Summary is required.";
    return null;
  }

  return {
    title: title?.trim() || "",
    summary: summary?.trim() || "",
    category: category?.trim() || "",
    difficulty: difficulty?.trim() || "",
    duration: duration?.trim() || "",
    image: image || "",
    description: description?.trim() || "",
    requiresAuth: !!requiresAuth,
    tags: tags || [],
    validate,
  };
}
