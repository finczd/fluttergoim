import { ref } from 'vue';
import { asset, formatBytes, timeText } from '../utils/format';

// 媒体预览浮层：收藏/文件视图的左栏与右栏共用同一个预览状态（对齐原编译版 openMediaPreview）。
const previewing = ref(null); // { kind:'image'|'video'|'file', url, title, sub?, size?, time? }

function openMedia(item) {
  const url = asset(item && item.file_url);
  if (!url) return { ok: false };
  if (item.type === 'image') previewing.value = { kind: 'image', url, title: item.file_name || '图片预览' };
  else if (item.type === 'video') previewing.value = { kind: 'video', url, title: item.file_name || '视频预览' };
  else previewing.value = { kind: 'file', url, title: item.file_name || '文件', sub: item.conversation_title || '', size: formatBytes(item.file_size), time: timeText(item.created_at, true) };
  return { ok: true };
}

function closePreview() {
  previewing.value = null;
}

function onKeydown(e) {
  if (e.key === 'Escape' && previewing.value) closePreview();
}

export function useMediaPreview() {
  return { previewing, openMedia, closePreview, onKeydown };
}
