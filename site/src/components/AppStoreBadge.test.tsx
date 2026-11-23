import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AppStoreBadge } from "./AppStoreBadge";

describe("AppStoreBadge", () => {
  afterEach(cleanup);

  it("links to the App Store page once the app is live", () => {
    render(<AppStoreBadge live />);
    const link = screen.getByRole("link", { name: "Télécharger Pulse dans l'App Store" });
    expect(link).toHaveAttribute("href", "https://apps.apple.com/fr/app/id6829265826");
    expect(screen.queryByText("Bientôt sur l'App Store")).not.toBeInTheDocument();
  });

  it("is not a link before release and says it is coming soon", () => {
    render(<AppStoreBadge live={false} />);
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
    expect(screen.getByText("Bientôt sur l'App Store")).toBeVisible();
  });

  it("follows APP_STORE_LIVE by default, which is false before release", () => {
    render(<AppStoreBadge />);
    expect(screen.queryByRole("link")).not.toBeInTheDocument();
    expect(screen.getByText("Bientôt sur l'App Store")).toBeVisible();
  });
});
