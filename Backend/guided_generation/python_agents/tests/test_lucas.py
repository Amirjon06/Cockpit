import unittest

from app.agents.lucas import LucasAgent


class MockModelClient:
    def __init__(self):
        self.call = None

    async def stream_completion(self, system_prompt, user_content, temperature):
        self.call = (system_prompt, user_content, temperature)
        for chunk in ("Opening ", "paragraph."):
            yield chunk


class LucasAgentTests(unittest.IsolatedAsyncioTestCase):
    async def test_streams_essay_and_builds_grounded_prompt(self):
        client = MockModelClient()
        agent = LucasAgent(client)
        payload = {
            "analysis": "Compare two energy policies.",
            "essayTopic": "Renewable energy policy",
            "essayType": "Comparative",
            "tone": "Persuasive",
            "length": "Concise",
            "citationStyle": "MLA",
            "outlines": [
                {
                    "type": "Introduction",
                    "title": "Policy tradeoffs",
                    "bullets": ["State the thesis"],
                }
            ],
            "sources": [
                {
                    "title": "Energy Outlook",
                    "author": "A. Researcher",
                    "year": 2025,
                    "domain": "example.org",
                    "snippet": "Renewable capacity increased.",
                }
            ],
        }

        chunks = [chunk async for chunk in agent.generate_stream(payload)]

        self.assertEqual(chunks, ["Opening ", "paragraph."])
        system_prompt, user_content, temperature = client.call
        self.assertIn("Tone: Persuasive", system_prompt)
        self.assertIn("Citation style: MLA", system_prompt)
        self.assertIn("roughly 600-900 words", system_prompt)
        self.assertIn("1. Policy tradeoffs", user_content)
        self.assertIn("[1] A. Researcher (2025), Energy Outlook", user_content)
        self.assertEqual(temperature, 0.4)

    async def test_accepts_frontend_aliases_and_defaults(self):
        client = MockModelClient()
        agent = LucasAgent(client)
        payload = {
            "outline": [{"type": "Conclusion", "description": "Close the essay"}],
            "selectedSources": [{"title": "Source", "text": "Evidence"}],
            "tone": "unsupported",
            "length": "unsupported",
            "citation": "unsupported",
        }

        _ = [chunk async for chunk in agent.generate_stream(payload)]

        system_prompt, _, _ = client.call
        self.assertIn("Tone: Academic", system_prompt)
        self.assertIn("Citation style: APA", system_prompt)
        self.assertIn("roughly 1,000-1,500 words", system_prompt)

    async def test_requires_outline(self):
        agent = LucasAgent(MockModelClient())
        with self.assertRaisesRegex(ValueError, "outline item"):
            _ = [
                chunk
                async for chunk in agent.generate_stream(
                    {"sources": [{"title": "Source"}]}
                )
            ]

    async def test_requires_source(self):
        agent = LucasAgent(MockModelClient())
        with self.assertRaisesRegex(ValueError, "source"):
            _ = [
                chunk
                async for chunk in agent.generate_stream(
                    {"outlines": [{"title": "Introduction"}]}
                )
            ]


if __name__ == "__main__":
    unittest.main()
