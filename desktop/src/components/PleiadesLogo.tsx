interface PleiadesLogoProps {
  className?: string;
}

export default function PleiadesLogo({ className }: PleiadesLogoProps) {
  return (
    <svg
      viewBox="0 0 32 32"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      {/* The 7 main stars of Pleiades in their approximate positions */}
      {/* Alcyone (brightest, center) */}
      <circle cx="16" cy="14" r="3" fill="currentColor" opacity="1" />
      {/* Atlas */}
      <circle cx="20" cy="10" r="2.2" fill="currentColor" opacity="0.9" />
      {/* Electra */}
      <circle cx="12" cy="11" r="2" fill="currentColor" opacity="0.85" />
      {/* Maia */}
      <circle cx="22" cy="16" r="1.8" fill="currentColor" opacity="0.8" />
      {/* Merope */}
      <circle cx="10" cy="17" r="1.8" fill="currentColor" opacity="0.75" />
      {/* Taygeta */}
      <circle cx="18" cy="20" r="1.6" fill="currentColor" opacity="0.7" />
      {/* Pleione */}
      <circle cx="24" cy="12" r="1.4" fill="currentColor" opacity="0.65" />
      {/* Subtle glow/nebula effect */}
      <circle cx="16" cy="15" r="10" fill="currentColor" opacity="0.08" />
    </svg>
  );
}
