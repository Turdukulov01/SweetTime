import { forwardRef, type InputHTMLAttributes, type TextareaHTMLAttributes } from 'react';
import { cn } from '@/lib/utils';

interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  error?: string;
  icon?: React.ReactNode;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ className, label, error, icon, id, ...props }, ref) => {
    const inputId = id ?? props.name;
    return (
      <div className="w-full">
        {label && (
          <label htmlFor={inputId} className="mb-1.5 block text-sm font-medium text-ink">
            {label}
          </label>
        )}
        <div className="relative">
          {icon && (
            <span className="pointer-events-none absolute left-4 top-1/2 -translate-y-1/2 text-ink-muted">
              {icon}
            </span>
          )}
          <input
            ref={ref}
            id={inputId}
            className={cn(
              'w-full rounded-2xl border-2 border-pink-100 bg-white px-4 py-3 font-body text-ink',
              'placeholder:text-ink-muted/70 transition-colors',
              'focus:border-pink-400 focus:outline-none focus:ring-2 focus:ring-pink-100',
              icon && 'pl-11',
              error && 'border-red-300 focus:border-red-400 focus:ring-red-100',
              'dark:bg-berry-700/40 dark:border-berry-300/30 dark:text-cream',
              className,
            )}
            {...props}
          />
        </div>
        {error && <p className="mt-1.5 text-sm text-red-500">{error}</p>}
      </div>
    );
  },
);
Input.displayName = 'Input';

interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  label?: string;
  error?: string;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  ({ className, label, error, id, ...props }, ref) => {
    const inputId = id ?? props.name;
    return (
      <div className="w-full">
        {label && (
          <label htmlFor={inputId} className="mb-1.5 block text-sm font-medium text-ink">
            {label}
          </label>
        )}
        <textarea
          ref={ref}
          id={inputId}
          className={cn(
            'w-full rounded-2xl border-2 border-pink-100 bg-white px-4 py-3 font-body text-ink',
            'placeholder:text-ink-muted/70 transition-colors',
            'focus:border-pink-400 focus:outline-none focus:ring-2 focus:ring-pink-100',
            'dark:bg-berry-700/40 dark:border-berry-300/30 dark:text-cream',
            className,
          )}
          {...props}
        />
        {error && <p className="mt-1.5 text-sm text-red-500">{error}</p>}
      </div>
    );
  },
);
Textarea.displayName = 'Textarea';
