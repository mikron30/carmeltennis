from __future__ import annotations

from datetime import UTC, datetime, timedelta, timezone
import unittest

from app.hikvision import (
    _build_download_xml,
    _build_search_xml,
    _parse_search_result,
    _select_playback_match,
)


SEARCH_RESPONSE = b"""<?xml version=\"1.0\"?>
<CMSearchResult xmlns=\"http://www.hikvision.com/ver20/XMLSchema\">
  <matchList>
    <searchMatchItem>
      <timeSpan>
        <startTime>2026-08-04T12:00:00+03:00</startTime>
        <endTime>2026-08-04T12:01:00+03:00</endTime>
      </timeSpan>
      <mediaSegmentDescriptor>
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
        self.assertRegex(xml, r"<searchID>[0-9a-f-]{36}</searchID>")

    def test_download_xml_escapes_playback_uri_query(self) -> None:
        xml = _build_download_xml("rtsp://nvr/track?start=1&end=2")

        self.assertIn("<playbackURI>rtsp://nvr/track?start=1&amp;end=2</playbackURI>", xml)

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
        self.assertEqual(chosen.segment_start, datetime(2026, 8, 4, 9, 0, tzinfo=UTC))  # type: ignore[union-attr]

    def test_parses_mislabelled_z_timestamp_as_configured_local_time(self) -> None:
        matches = _parse_search_result(
            SEARCH_RESPONSE.replace(b"+03:00", b"Z"),
            local_wall_clock_timezone=timezone(timedelta(hours=3)),
        )

        self.assertEqual(matches[0].segment_start, datetime(2026, 8, 4, 9, 0, tzinfo=UTC))


if __name__ == "__main__":
    unittest.main()
