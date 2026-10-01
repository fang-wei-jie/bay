import { InstallCheck } from "@/types/preferences";
import { Fig, Internal } from "@aws/amazon-q-developer-cli-api-bindings";
import { useEffect, useState } from "react";
import { Button } from "../../ui/button";
import Lockup from "../../svg/logo";
import onboarding from "@/data/onboarding";
import { useStatusCheck } from "@/hooks/store/useStatusCheck";
import InstallModal from "./install";
import { useRefreshLocalState } from "@/hooks/store/useState";
import { usePlatformInfo } from "@/hooks/store/usePlatformInfo";
import { matchesPlatformRestrictions } from "@/lib/platform";

export default function OnboardingModal() {
  const [step, setStep] = useState(0);
  const check = onboarding[step] as InstallCheck;
  const [dotfilesCheck, refreshDotfiles] = useStatusCheck("dotfiles");
  const [accessibilityCheck, refreshAccessibility] =
    useStatusCheck("accessibility");
  const [_desktopEntryCheck, refreshDesktopEntry] =
    useStatusCheck("desktopEntry");
  const [_gnomeExtensionCheck, refreshGnomeExtension] =
    useStatusCheck("gnomeExtension");
  const refreshLocalState = useRefreshLocalState();
  const platformInfo = usePlatformInfo();

  const [_dotfiles, setDotfiles] = useState(dotfilesCheck);
  const [_accessibility, setAccessibility] = useState(accessibilityCheck);

  useEffect(() => {
    refreshAccessibility();
    refreshDotfiles();
    refreshDesktopEntry();
    refreshGnomeExtension();
  }, [
    refreshAccessibility,
    refreshDotfiles,
    refreshDesktopEntry,
    refreshGnomeExtension,
  ]);

  function finish() {
    refreshAccessibility();
    refreshDotfiles();
    refreshDesktopEntry();
    refreshGnomeExtension();
    Internal.sendOnboardingRequest({
      action: Fig.OnboardingAction.FINISH_ONBOARDING,
    })
      .then(() => {
        refreshLocalState().catch((err) => console.error(err));
      })
      .catch((err) => console.error(err));
  }

  function advance() {
    if (step === onboarding.length - 1) {
      finish();
    } else {
      setStep(step + 1);
    }
  }

  function skipInstall() {
    if (!check.id) return;

    if (check.id === "dotfiles") setDotfiles(true);
    if (check.id === "accessibility") setAccessibility(true);

    advance();
  }

  // Skip steps for other platforms. Goes through advance() so skipping the
  // last step finishes onboarding instead of indexing past the end.
  const skipStep =
    !!platformInfo &&
    !matchesPlatformRestrictions(platformInfo, check.platformRestrictions);

  useEffect(() => {
    if (skipStep) advance();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [skipStep, step]);

  if (skipStep) {
    return null;
  }

  if (check.id === "welcome") {
    return <WelcomeModal next={advance} />;
  }

  if (
    ["dotfiles", "accessibility", "gnomeExtension", "desktopEntry"].includes(
      check.id,
    )
  ) {
    return <InstallModal check={check} skip={skipInstall} next={advance} />;
  }

  return null;
}

export function WelcomeModal({ next }: { next: () => void }) {
  return (
    <div className="flex flex-col items-center gap-8 gradient-q-secondary-light -m-10 p-4 pt-10 rounded-lg text-white">
      <div className="flex flex-col items-center gap-8">
        <Lockup />
        <div className="flex flex-col gap-2 items-center text-center">
          <h2 className="text-2xl text-white font-semibold select-none leading-none font-ember tracking-tight">
            Welcome!
          </h2>
          <p className="text-sm">Let's get you set up...</p>
        </div>
      </div>
      <div className="flex flex-col items-center gap-2 text-white text-sm font-bold">
        <Button variant="glass" onClick={() => next()} className="flex gap-4">
          Get started
        </Button>
      </div>
    </div>
  );
}
