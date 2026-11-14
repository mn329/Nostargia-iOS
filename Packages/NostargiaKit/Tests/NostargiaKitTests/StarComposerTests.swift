import Foundation
import Testing
@testable import NostargiaKit

struct StarComposerTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func normalizesGoodThings() {
        #expect(DiaryEntry.normalize(["  散歩  ", "", "\u{3000}", "カフェ", "読書", "映画"]) == ["散歩", "カフェ", "読書"])
    }

    @Test func usesLetterWhenAvailable() {
        var random = SequenceRandom([0.5])
        let entry = DiaryEntry(mood: MoodValues(all: 20), goodThings: [" 散歩 "], tag: TagRef(id: "t1", name: "休日"))
        let draft = StarComposer.draft(entry: entry, existing: [], letter: "星からの手紙", now: now, random: &random)
        #expect(draft.feedback == "星からの手紙")
        #expect(draft.emotion == "消耗・虚無")
        #expect(draft.totalScore == 20)
        #expect(draft.goodThings == ["散歩"])
        #expect(draft.tag == TagRef(id: "t1", name: "休日"))
        #expect(draft.displayDate == now)
        #expect(draft.mood == MoodValues(all: 20))
        #expect(!draft.isTutorial)
    }

    @Test func fallsBackToTemplateLetter() {
        var random = SequenceRandom([0.5])
        let entry = DiaryEntry(mood: MoodValues(all: 20), goodThings: ["散歩"], tag: nil)
        let draft = StarComposer.draft(entry: entry, existing: [], letter: nil, now: now, random: &random)
        #expect(draft.feedback == MoodAnalyzer.analyze(MoodValues(all: 20), goodThings: ["散歩"]).fallbackFeedback)
    }

    @Test func matchesStarFactoryBlueprint() {
        let mood = MoodValues(all: 80)
        var a = SequenceRandom([0.5, 0.3, 0.7])
        var b = SequenceRandom([0.5, 0.3, 0.7])
        let draft = StarComposer.draft(entry: DiaryEntry(mood: mood, goodThings: [], tag: nil), existing: [], letter: nil, now: now, random: &a)
        let blueprint = StarFactory.make(mood: mood, existing: [], random: &b)
        #expect(draft.position == blueprint.position)
        #expect(draft.color == blueprint.color)
        #expect(draft.scale == blueprint.scale)
        #expect(draft.random == blueprint.random)
        #expect(draft.constellation == blueprint.constellation)
    }

    @Test func existingConstellationStarsAreRespected() {
        let taken = Star(
            id: "s1",
            createdAt: nil,
            draft: StarDraft(
                position: StarPosition(x: 0, y: 0, z: 0), color: StarColor(r: 1, g: 1, b: 1), scale: 2, random: 0,
                displayDate: now, mood: MoodValues(all: 80), emotion: "", feedback: "", totalScore: 80,
                goodThings: [], tag: nil, constellation: ConstellationAssignment(id: "andromeda", nodeIndex: 0), isTutorial: false
            )
        )
        var random = SequenceRandom([0.5])
        let draft = StarComposer.draft(entry: DiaryEntry(mood: MoodValues(all: 80), goodThings: [], tag: nil), existing: [taken], letter: nil, now: now, random: &random)
        #expect(draft.constellation == ConstellationAssignment(id: "andromeda", nodeIndex: 1))
    }
}
