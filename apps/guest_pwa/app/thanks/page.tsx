export default function ThanksPage() {
  return (
    <main
      className="fade-in"
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: '100dvh',
        padding: 24,
        textAlign: 'center',
        position: 'relative',
        overflow: 'hidden',
        background:
          'radial-gradient(1200px 800px at 50% -10%, #2a1d12 0%, #120b07 55%, #0a0604 100%)',
      }}
    >
      <FrameMark />
      <h1
        className="mora-display-hero"
        style={{ fontSize: 36, lineHeight: 1.05, margin: '20px 0 8px', color: 'var(--text-primary)' }}
      >
        You&apos;re all set
      </h1>
      <p style={{ color: 'var(--text-secondary)', fontSize: 15, maxWidth: 280, lineHeight: 1.5, margin: 0 }}>
        Your photos will appear here when the film develops.
      </p>
    </main>
  );
}

function FrameMark() {
  return (
    <svg width="28" height="28" viewBox="0 0 24 24" aria-hidden style={{ opacity: 0.9 }}>
      <rect x="6" y="4" width="12" height="2.4" rx="1.1" fill="#D9A85C" opacity="0.45" />
      <rect x="4.75" y="7.5" width="14.5" height="13" rx="2.5" fill="none" stroke="#D9A85C" strokeWidth="1.5" />
      <circle cx="12" cy="14" r="2.1" fill="#D9A85C" />
    </svg>
  );
}
