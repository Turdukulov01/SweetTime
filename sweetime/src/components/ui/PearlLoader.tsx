export function PearlLoader({ label = 'Завариваем…' }: { label?: string }) {
  return (
    <div className="flex flex-col items-center justify-center gap-3 py-16" role="status" aria-live="polite">
      <div className="relative h-16 w-12 overflow-hidden rounded-b-full rounded-t-lg border-2 border-berry-300/40 bg-cream-deep">
        <span className="absolute bottom-1 left-1.5 h-2 w-2 animate-pearl-rise rounded-full bg-berry-500 [animation-delay:0ms]" />
        <span className="absolute bottom-1 left-4 h-2 w-2 animate-pearl-rise rounded-full bg-berry-500 [animation-delay:400ms]" />
        <span className="absolute bottom-1 left-6 h-2 w-2 animate-pearl-rise rounded-full bg-berry-500 [animation-delay:800ms]" />
      </div>
      <p className="font-body text-sm text-ink-muted">{label}</p>
    </div>
  );
}
