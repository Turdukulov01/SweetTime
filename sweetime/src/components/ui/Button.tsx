'use client';

import { forwardRef } from 'react';
import { motion, type HTMLMotionProps } from 'framer-motion';
import { Loader2 } from 'lucide-react';
import { cn } from '@/lib/utils';

type Variant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger';
type ButtonSize = 'sm' | 'md' | 'lg';

interface ButtonProps extends Omit<HTMLMotionProps<'button'>, 'ref'> {
  variant?: Variant;
  size?: ButtonSize;
  isLoading?: boolean;
  fullWidth?: boolean;
}

const variantClasses: Record<Variant, string> = {
  primary:
    'bg-berry-500 text-cream hover:bg-berry-600 shadow-soft hover:shadow-lifted focus-visible:shadow-glow',
  secondary:
    'bg-pink-300 text-berry-600 hover:bg-pink-400 shadow-soft hover:shadow-lifted focus-visible:shadow-glow',
  outline:
    'bg-transparent border-2 border-berry-500 text-berry-500 hover:bg-berry-500 hover:text-cream',
  ghost: 'bg-transparent text-berry-500 hover:bg-berry-50 dark:hover:bg-berry-700/30',
  danger: 'bg-red-500 text-white hover:bg-red-600 shadow-soft',
};

const sizeClasses: Record<ButtonSize, string> = {
  sm: 'text-sm px-4 py-2 gap-1.5',
  md: 'text-base px-6 py-3 gap-2',
  lg: 'text-lg px-8 py-4 gap-2.5',
};

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  (
    { className, variant = 'primary', size = 'md', isLoading, fullWidth, children, disabled, ...props },
    ref,
  ) => {
    return (
      <motion.button
        ref={ref}
        whileTap={{ scale: 0.96 }}
        whileHover={{ y: -1 }}
        transition={{ type: 'spring', stiffness: 400, damping: 25 }}
        disabled={disabled || isLoading}
        className={cn(
          'inline-flex items-center justify-center rounded-pearl font-body font-semibold',
          'transition-colors duration-200 disabled:cursor-not-allowed disabled:opacity-50',
          'focus-visible:outline-none',
          variantClasses[variant],
          sizeClasses[size],
          fullWidth && 'w-full',
          className,
        )}
        {...props}
      >
        {isLoading && <Loader2 className="h-4 w-4 animate-spin" aria-hidden />}
        {children}
      </motion.button>
    );
  },
);
Button.displayName = 'Button';
