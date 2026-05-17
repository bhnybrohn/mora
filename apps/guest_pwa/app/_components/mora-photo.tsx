// MoraPhoto — procedural warm "wedding photo" placeholder. Mirrors
// project/photos.jsx from the design bundle so what the user sees here lines
// up with the prototype. No real imagery, no faces.

import { CSSProperties, ReactNode, useMemo } from 'react';

const PALETTES: [string, string, string][] = [
  ['#231209', '#D9A85C', '#7A3318'],
  ['#1B0F0A', '#E6B66B', '#3D1A0E'],
  ['#2A1A0D', '#F1C57E', '#5C2A14'],
  ['#181009', '#C77859', '#2B130A'],
  ['#13110D', '#A47C40', '#3A2515'],
  ['#241006', '#FAD18D', '#7A3A1A'],
  ['#1F1408', '#D89F4A', '#48200D'],
  ['#150C07', '#B58A4B', '#341905'],
  ['#2C1A0E', '#EFB964', '#6E2E14'],
  ['#1A0D07', '#E8A75A', '#522010'],
];

function mulberry32(a: number) {
  return function () {
    let t = (a += 0x6d2b79f5);
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

interface Blob {
  cx: number;
  cy: number;
  r: number;
  c: string;
  a: number;
}

export function MoraPhoto({
  seed = 0,
  style,
  className,
  focal,
  children,
}: {
  seed?: number;
  style?: CSSProperties;
  className?: string;
  focal?: { x: number; y: number };
  children?: ReactNode;
}) {
  const palette = PALETTES[seed % PALETTES.length];
  const [base, glow, lift] = palette;
  const id = `mp-${seed}`;
  const fx = focal?.x ?? 50;
  const fy = focal?.y ?? 55;

  const blobs: Blob[] = useMemo(() => {
    const rng = mulberry32(seed * 1973 + 31);
    const n = 2 + Math.floor(rng() * 3);
    const arr: Blob[] = [];
    for (let i = 0; i < n; i++) {
      arr.push({
        cx: 10 + rng() * 80,
        cy: 20 + rng() * 70,
        r: 18 + rng() * 32,
        c: i === 0 ? glow : rng() < 0.5 ? lift : glow,
        a: 0.35 + rng() * 0.45,
      });
    }
    return arr;
  }, [seed, glow, lift]);

  return (
    <div
      className={className}
      style={{ position: 'relative', background: base, overflow: 'hidden', ...style }}
    >
      <svg
        viewBox="0 0 100 100"
        preserveAspectRatio="xMidYMid slice"
        style={{ position: 'absolute', inset: 0, width: '100%', height: '100%', display: 'block' }}
      >
        <defs>
          <radialGradient id={`${id}-bg`} cx={`${fx}%`} cy={`${fy}%`} r="75%">
            <stop offset="0%" stopColor={glow} stopOpacity="0.35" />
            <stop offset="55%" stopColor={base} stopOpacity="0" />
            <stop offset="100%" stopColor="#000" stopOpacity="0.45" />
          </radialGradient>
          <filter id={`${id}-blur`} x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="3.5" />
          </filter>
          <radialGradient id={`${id}-vignette`} cx="50%" cy="50%" r="75%">
            <stop offset="55%" stopColor="#000" stopOpacity="0" />
            <stop offset="100%" stopColor="#000" stopOpacity="0.55" />
          </radialGradient>
        </defs>
        <rect width="100" height="100" fill={base} />
        {blobs.map((b, i) => (
          <circle
            key={i}
            cx={b.cx}
            cy={b.cy}
            r={b.r}
            fill={b.c}
            opacity={b.a}
            filter={`url(#${id}-blur)`}
          />
        ))}
        <rect width="100" height="100" fill={`url(#${id}-bg)`} />
        <rect width="100" height="100" fill={`url(#${id}-vignette)`} />
      </svg>
      {children}
    </div>
  );
}
