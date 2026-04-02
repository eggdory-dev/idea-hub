const WEBHOOK_URL = process.env.DISCORD_WEBHOOK_URL;

export async function sendDiscordNotification(message: string): Promise<void> {
  if (!WEBHOOK_URL) {
    console.warn("Discord webhook URL not set, skipping notification");
    return;
  }

  try {
    await fetch(WEBHOOK_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        content: message,
      }),
    });
  } catch (error) {
    console.error("Failed to send Discord notification:", error);
  }
}
