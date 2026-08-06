from __future__ import annotations

from datetime import UTC, datetime
import unittest

from app.hikvision import _build_search_xml, _parse_search_result, _select_playback_match


SEARCH_RESPONSE = b"""<?xml version=\"1.0\"?>
<CMSearchResult xmlns=\"http://www.hikvision.com/ver20/XMLSchema\">
  <matchList>
    <searchMatchItem>
      <mediaSegmentDescriptor>
        <startTime>2026-08-04T12:00:00+03:00</startTime>
        <endTime>2026-08-04T12:01:00+03:00</endTime>
        <playbackURI>rtsp://nvr/Streaming/tracks/401?starttime=20260804T120000Z</playbackURI>
      </mediaSegmentDescriptor>
    </searchMatchItem>
  </matchList>
</CMSearchResult>"""


class HikvisionSearchTest(unittest.TestCase):
    def test_search_xml_uses_logical_track_and_interval(self) -> None:
        xml = _build_search_xml(
            track_id="401",
            start="2026-08-04T12:00:00+03:00",
            end="2026-08-04T12:00:10+03:00",
        )

        self.assertIn("<trackID>401</trackID>", xml)
        self.assertIn("<startTime>2026-08-04T12:00:00+03:00</startTime>", xml)

    def test_finds_nested_playback_uri_and_overlapping_segment(self) -> None:
        matches = _parse_search_result(SEARCH_RESPONSE)
        chosen = _select_playback_match(
            matches,
            datetime(2026, 8, 4, 9, 0, 5, tzinfo=UTC),
            datetime(2026, 8, 4, 9, 0, 10, tzinfo=UTC),
        )

        self.assertEqual(len(matches), 1)
        self.assertIsNotNone(chosen)
        self.assertTrue(chosen.playback_uri.startswith("rtsp://"))  # type: ignore[union-attr]


if __name__ == "__main__":
    unittest.main()
