import Testing
@testable import KOTCore

@Suite struct SpaceIDTests {
    @Test func bareID() {
        #expect(SpaceID.normalize("AAAABBBBCCCC") == "AAAABBBBCCCC")
    }

    @Test func apiFormat() {
        #expect(SpaceID.normalize("spaces/AAAABBBBCCCC") == "AAAABBBBCCCC")
    }

    @Test func roomURL() {
        #expect(SpaceID.normalize("https://chat.google.com/room/AAAA-BBBB_cccc") == "AAAA-BBBB_cccc")
    }

    @Test func roomURLWithQuery() {
        #expect(SpaceID.normalize("https://chat.google.com/room/XYZ123?cls=1") == "XYZ123")
    }
}
