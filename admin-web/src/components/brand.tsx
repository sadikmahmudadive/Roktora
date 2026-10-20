const DROP =
  "M875 450C855 560 880 650 960 760C1040 870 1212 980 1212 1130C1212 1320 1060 1470 875 1470C690 1470 530 1320 530 1120C530 1030 560 930 597 852C555 960 545 1080 625 1180C655 1218 680 1240 710 1240C745 1240 765 1200 745 1170C735 1150 715 1138 700 1125C640 1070 615 990 620 900C630 740 760 570 875 450Z";

/** The Roktora blood-drop mark. */
export function RoktoraMark({ height = 26, className }: { height?: number; className?: string }) {
  return (
    <svg viewBox="520 440 702 1040" height={height} aria-hidden className={className} style={{ width: "auto" }}>
      <path d={DROP} fill="currentColor" />
    </svg>
  );
}

export function Wordmark() {
  return (
    <span className="inline-flex items-center gap-2.5">
      <RoktoraMark className="text-brand" />
      <span className="text-[17px] font-bold tracking-tight">Roktora</span>
    </span>
  );
}
