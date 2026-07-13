import { useEffect, type RefObject } from 'react';

export function useClickOutside<T extends HTMLElement>(
  ref: RefObject<T | null>,
  onOutsideClick: () => void,
) {
  useEffect(() => {
    function handler(event: MouseEvent) {
      if (ref.current && !ref.current.contains(event.target as Node)) {
        onOutsideClick();
      }
    }
    document.addEventListener('mousedown', handler);
    return () => document.removeEventListener('mousedown', handler);
  }, [ref, onOutsideClick]);
}
