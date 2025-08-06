// src/entity/viewServiceEntity.js
export function serviceEntity(rawData) {
  const { title, description, details } = rawData;

  function validate() {
    if (!title || !title.trim()) return "Title is required.";
    if (!description || !description.trim()) return "Description is required.";
    return null;
  }

  return {
    title: title?.trim(),
    description: description?.trim(),
    details: details?.trim() || "",
    validate,
  };
}
