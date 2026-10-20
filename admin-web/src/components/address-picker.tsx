"use client";

import { LocateFixed, Search } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { Banner, Button } from "./ui";

// Minimal slice of the Google Maps JS API that this component uses (no @types dependency).
interface LatLng { lat: number; lng: number }
interface GMap { setCenter(p: LatLng): void; setZoom(z: number): void; addListener(e: string, cb: (ev: { latLng: { lat(): number; lng(): number } }) => void): void }
interface GMarker { setPosition(p: LatLng): void; setMap(m: GMap | null): void; addListener(e: string, cb: () => void): void; getPosition(): { lat(): number; lng(): number } }
interface GGeocoder { geocode(req: { address?: string; location?: LatLng }): Promise<{ results: { formatted_address: string; geometry: { location: { lat(): number; lng(): number } } }[] }> }
interface GMaps {
  Map: new (el: HTMLElement, o: object) => GMap;
  Marker: new (o: object) => GMarker;
  Geocoder: new () => GGeocoder;
  importLibrary(name: "maps" | "geocoding"): Promise<unknown>;
}
declare global {
  interface Window { google?: { maps: GMaps }; __roktoraMapsReady?: () => void }
}

const KEY = process.env.NEXT_PUBLIC_GOOGLE_MAPS_API_KEY;
const DHAKA: LatLng = { lat: 23.8103, lng: 90.4125 };

let loader: Promise<GMaps> | null = null;
function loadMaps(): Promise<GMaps> {
  if (typeof window === "undefined") return Promise.reject(new Error("no window"));
  if (window.google?.maps?.Map) return Promise.resolve(window.google.maps);
  loader ??= new Promise<GMaps>((resolve, reject) => {
    // With loading=async the bootstrap calls back first; the classes are then imported on demand.
    window.__roktoraMapsReady = () => {
      const maps = window.google!.maps;
      Promise.all([maps.importLibrary("maps"), maps.importLibrary("geocoding")]).then(() => resolve(maps), reject);
    };
    const s = document.createElement("script");
    s.src = `https://maps.googleapis.com/maps/api/js?key=${encodeURIComponent(KEY ?? "")}&loading=async&callback=__roktoraMapsReady&v=weekly`;
    s.async = true;
    s.onerror = () => {
      loader = null;
      reject(new Error("load failed"));
    };
    document.head.appendChild(s);
  });
  return loader;
}

export interface PickedPlace { address: string; lat: number; lng: number }

/**
 * Pick a hospital's address on Google Maps: search, click the map or drag the pin.
 * Reports the street address (reverse-geocoded) with its coordinates.
 */
export function AddressPicker({ lat, lng, disabled, onPick }: { lat?: number | null; lng?: number | null; disabled?: boolean; onPick: (p: PickedPlace) => void }) {
  const el = useRef<HTMLDivElement>(null);
  const api = useRef<{ maps: GMaps; map: GMap; marker: GMarker; geocoder: GGeocoder } | null>(null);
  const pick = useRef(onPick);
  const [q, setQ] = useState("");
  const [error, setError] = useState<string | null>(KEY ? null : "Add NEXT_PUBLIC_GOOGLE_MAPS_API_KEY to .env.local and restart to use the map.");
  const [busy, setBusy] = useState(false);
  const start = useRef<LatLng>(typeof lat === "number" && typeof lng === "number" ? { lat, lng } : DHAKA);

  useEffect(() => {
    pick.current = onPick;
  });

  useEffect(() => {
    if (!KEY) return;
    let cancelled = false;
    loadMaps()
      .then((maps) => {
        if (cancelled || !el.current) return;
        const at = start.current;
        const map = new maps.Map(el.current, { center: at, zoom: lat != null ? 16 : 11, mapTypeControl: false, streetViewControl: false, fullscreenControl: false, clickableIcons: false });
        const marker = new maps.Marker({ map: lat != null ? map : null, position: at, draggable: !disabled });
        const geocoder = new maps.Geocoder();
        api.current = { maps, map, marker, geocoder };

        const place = async (p: LatLng) => {
          marker.setPosition(p);
          marker.setMap(map);
          setBusy(true);
          try {
            const { results } = await geocoder.geocode({ location: p });
            pick.current({ address: results[0]?.formatted_address ?? "", lat: p.lat, lng: p.lng });
            setError(null);
          } catch {
            pick.current({ address: "", lat: p.lat, lng: p.lng });
            setError("Pinned, but couldn't look up the street address. Type it in.");
          } finally {
            setBusy(false);
          }
        };
        if (!disabled) {
          map.addListener("click", (ev) => void place({ lat: ev.latLng.lat(), lng: ev.latLng.lng() }));
          marker.addListener("dragend", () => {
            const pos = marker.getPosition();
            void place({ lat: pos.lat(), lng: pos.lng() });
          });
        }
      })
      .catch(() => !cancelled && setError("Google Maps didn't load. Check the API key, that Maps JavaScript API is enabled, and the key's allowed websites."));
    return () => {
      cancelled = true;
    };
    // The map is created once; later prop changes must not rebuild it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  async function search() {
    const a = api.current;
    if (!a || !q.trim()) return;
    setBusy(true);
    setError(null);
    try {
      const { results } = await a.geocoder.geocode({ address: q.trim() });
      const r = results[0];
      if (!r) {
        setError("No place found for that search.");
        return;
      }
      const p = { lat: r.geometry.location.lat(), lng: r.geometry.location.lng() };
      a.map.setCenter(p);
      a.map.setZoom(16);
      a.marker.setPosition(p);
      a.marker.setMap(a.map);
      onPick({ address: r.formatted_address, ...p });
    } catch {
      setError("Couldn't search just now. Click the map to drop a pin instead.");
    } finally {
      setBusy(false);
    }
  }

  function locate() {
    const a = api.current;
    if (!a || !navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      async (pos) => {
        const p = { lat: pos.coords.latitude, lng: pos.coords.longitude };
        a.map.setCenter(p);
        a.map.setZoom(16);
        a.marker.setPosition(p);
        a.marker.setMap(a.map);
        try {
          const { results } = await a.geocoder.geocode({ location: p });
          onPick({ address: results[0]?.formatted_address ?? "", ...p });
        } catch {
          onPick({ address: "", ...p });
        }
      },
      () => setError("Couldn't get your location. Allow location access, or search instead."),
    );
  }

  return (
    <div>
      {!disabled && (
        <div className="mb-2 flex gap-2">
          <div className="relative min-w-0 flex-1">
            <Search size={16} className="pointer-events-none absolute top-1/2 left-3.5 -translate-y-1/2 text-ink-3" />
            <input
              aria-label="Search for the hospital on the map"
              placeholder="Search the hospital or address"
              value={q}
              onChange={(e) => setQ(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  void search();
                }
              }}
              className="w-full rounded-[var(--radius-ctl)] border border-line-2 bg-surface-0 py-2.5 pr-3 pl-10 text-[15px] text-ink placeholder:text-ink-3 focus:border-brand focus:ring-2 focus:ring-brand-bg"
            />
          </div>
          <Button variant="outline" disabled={busy || !q.trim()} onClick={() => void search()}>Search</Button>
          <Button variant="outline" aria-label="Use my current location" icon={<LocateFixed size={16} />} onClick={locate} />
        </div>
      )}
      <div ref={el} role="application" aria-label="Map" className="h-64 w-full overflow-hidden rounded-[var(--radius-ctl)] border border-line bg-surface-2" />
      <p className="mt-1.5 text-xs text-ink-3">{disabled ? "Pinned location." : "Search, click the map, or drag the pin. The address above fills in for you."}</p>
      {error && <Banner className="mt-2" tone="warning">{error}</Banner>}
    </div>
  );
}
