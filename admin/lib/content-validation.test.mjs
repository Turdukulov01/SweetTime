import assert from "node:assert/strict";
import test from "node:test";
import {
  fromDateTimeLocal,
  localizedPublishError,
  mediaTypeForFile,
  validateMediaFile
} from "./content-validation.ts";

test("publishing reports missing KY and EN translations", () => {
  assert.equal(
    localizedPublishError({ ru: "Новость", ky: "", en: "" }),
    "Для публикации заполните: KY, EN"
  );
  assert.equal(
    localizedPublishError({ ru: "Новость", ky: "Жаңылык", en: "News" }),
    null
  );
});

test("content media accepts production image and MP4 limits", () => {
  const image = { name: "cover.webp", type: "image/webp", size: 10 * 1024 * 1024 };
  const video = { name: "story.mp4", type: "video/mp4", size: 50 * 1024 * 1024 };
  assert.equal(validateMediaFile(image, false), null);
  assert.equal(validateMediaFile(video, true), null);
  assert.equal(mediaTypeForFile(video), "video");
});

test("collection cover rejects video and oversized image", () => {
  const video = { name: "cover.mp4", type: "video/mp4", size: 1024 };
  const oversized = {
    name: "cover.jpg",
    type: "image/jpeg",
    size: 10 * 1024 * 1024 + 1
  };
  assert.match(validateMediaFile(video, false) ?? "", /только JPEG/);
  assert.match(validateMediaFile(oversized, false) ?? "", /10 МиБ/);
});

test("local datetime becomes an ISO instant", () => {
  const iso = fromDateTimeLocal("2026-07-15T12:30");
  assert.ok(iso);
  assert.equal(Number.isNaN(Date.parse(iso)), false);
});
