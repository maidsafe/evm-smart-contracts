// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/src/Script.sol";
import "forge-std/src/console.sol";
import {AppRegistry} from "../src/AppRegistry.sol";

contract RegisterApps is Script {
    address public sender = 0xf14176Fe20d87fb763eF908C378B0FbF595c32a1;
    AppRegistry public appRegistry = AppRegistry(0x81feC66E8eE72cfa971761eD241B7D0e91a4D122);

    function run() external {
        console.log("starting apps registration");

        uint256 deployerPrivKey = vm.envUint("KEY_MAINNET");
        vm.startBroadcast(deployerPrivKey);

        appRegistry.registerApp(
            sender,
            "w3b.site",
            "Unleash the power of your imagination. Combine visuals, sounds, texts and links in an immersive user interface. Redefining the concept of websites, transforming them into a blank canvas for all kinds of free expressions. A unique, uncensorable, and eternal medium living in a trustable and tradable NFT minted on your own Wallet with it's Domain Name as URL to surf it on Web3 browsers! (Powered by Unstoppable Domains +. Autonomi Network)Web3 Top Level Domain  .W3B",
            "https://impossible-futures.com/projects/w3b-site"
        );

        /*         // 1
        appRegistry.registerApp(
            sender,
            "AI FitBuddy",
            "A smart little app in your phone. It tells you: what exercises to do, how many times, and when to rest. It remembers everything for you and knows what to do next so you can get stronger. It's like having a coach in your pocket!",
            "https://impossible-futures.com/projects/ai-fitbuddy"
        );

        // 2
        appRegistry.registerApp(
            sender,
            "AntAI",
            "Meet AntAI the decentralized, open-source AI assistant built for privacy. Automate tasks, streamline coding, and chat securely knowing your data stays encrypted, private, and fully yours.",
            "https://impossible-futures.com/projects/antai"
        );

        // 3
        appRegistry.registerApp(
            sender,
            "AntChain - Time-Proof Your Truth",
            "AntChain addresses a simple but serious problem: how can you prove you made or said something first? Traditional archives and file uploads can be faked or erased. Blockchain systems can be expensive or limited. AntChain is lightweight, decentralized, and transparent.",
            "https://impossible-futures.com/projects/antchain-time-proof-your-truth"
        );

        // 4
        appRegistry.registerApp(
            sender,
            "ArbiTrack",
            "Your Wallets. Your Stats. Your Rules. Combine your wallets. Track everything. Sleep easy.",
            "https://impossible-futures.com/projects/arbitrack"
        );

        // 5
        appRegistry.registerApp(
            sender,
            "Ark",
            "Backups & Archives That Stand the Test of Time. Ark makes your important data permanent. Pay once, restore it anytime, even decades later. Only you are in control.Your Data. Archived. Forever.",
            "https://impossible-futures.com/projects/ark"
        );

        // 6
        appRegistry.registerApp(
            sender,
            "ArtistView(AV)",
            "An immersive front-end player for live concert films and exclusive private performances. Storing rare, high-quality concert footage - unstoppable, unowned, and always accessible. Unlocking exclusive, never-before-seen footage and behind-the-scenes archives.",
            "https://impossible-futures.com/projects/artistview(av)"
        );

        // 7
        appRegistry.registerApp(
            sender,
            "Auto Wallet - Application Framework",
            "AutoWallet provides a framework for developers to easily build with modern tooling, benefiting from security and built-in node earnings to make network interactions even more seamless.",
            "https://impossible-futures.com/projects/auto-wallet-application-framework"
        );

        // 8
        appRegistry.registerApp(
            sender,
            "Autonomi Browser Extension",
            "SafeBox is a way to bridge the billions of internet users to the Autonomi network. You can upload & download to the Autonomi network and even view, listen to & watch Autonomi files on the browser.",
            "https://impossible-futures.com/projects/autonomi-browser-extension"
        );

        // 9
        appRegistry.registerApp(
            sender,
            "Autonomi Community Token",
            "A token standard for Autonomi",
            "https://impossible-futures.com/projects/autonomi-community-token"
        );

        // 10
        appRegistry.registerApp(
            sender,
            "Autonomi Transaction Reporter",
            "Creates tax reports from blockchain transactions.",
            "https://impossible-futures.com/projects/autonomi-transaction-reporter"
        );

        // 11
        appRegistry.registerApp(
            sender,
            "AutonomiNet",
            "A C# library that empowers .NET developers to build truly decentralized applications on the Autonomi infrastructure - with zero central servers, full privacy, and unstoppable data storage. The goal? Making decentralized development accessible to the .NET ecosystem with a seamless, native API for Autonomi.",
            "https://impossible-futures.com/projects/autonominet"
        );

        // 12
        appRegistry.registerApp(
            sender,
            "AutVid",
            "Upload, transcode, and stream your videos on the Autonomi Network-no servers, no gatekeepers.",
            "https://impossible-futures.com/projects/autvid"
        );

        // 13
        appRegistry.registerApp(
            sender,
            "Ryyn",
            "Anything on your device can be made secure, permanent, and accessible-only to you and those you choose. It stays in sync across devices, instantly reflects your changes, and survives anything: phone lost, drive crashed, system wiped. What you have is always there-without needing to think about it. No setup. No friction. You use your key. You choose what to sync. That's it. This tool does exactly what it should: powerful, silent, invisible.",
            "https://impossible-futures.com/projects/ryyn"
        );

        // 14
        appRegistry.registerApp(
            sender,
            "CanMan",
            "The world's first decentralized Rentable 'CANtainers'  for NodeRunner Operators- rent low-cost, secure, XOR address masked LXC containers and storage to help other run their distributed apps more securely.",
            "https://impossible-futures.com/projects/canman"
        );

        // 15
        appRegistry.registerApp(
            sender,
            "Colony",
            "With Autonomi, we are finally free to host content forever, without fears of censorship or link rot. The problem is, how do you easily share that data with your friends? Or search for things that interest you? Or remember where all of your data is stored? Colony is an easy to use GUI that solves these problems to bring Autonomi to the masses.",
            "https://impossible-futures.com/projects/colony"
        );

        // 16
        appRegistry.registerApp(
            sender,
            "Friends",
            "Talking to your Friends directly and without any middlemen. No artificial intermediaries; no overhead; just p2p communication - you and your friends. <br> the hole-punching and live-comms libraries are planned to be released for rust, nodejs and python and can be used for other purposes too. The chat itself is meant to become a Webcomponent that can be included by any app that want's it. ",
            "https://impossible-futures.com/projects/friends"
        );

        // 17
        appRegistry.registerApp(
            sender,
            "Historical Weather Data",
            "A decentralized archive for exploring historical weather data - preserving climate records for open access and public insight.",
            "https://impossible-futures.com/projects/historical-weather-data"
        );

        // 18
        appRegistry.registerApp(
            sender,
            "IMIM",
            "Web application that allows anyone to create immutable blogs, rich with media, which cannot be silenced or censored. Authors can choose to be anonymous, but verifiable or public and irrefutable. I aM IMmutable! Are you?",
            "https://impossible-futures.com/projects/imim"
        );

        // 19
        appRegistry.registerApp(
            sender,
            "Memories",
            "A gallery app that lets you store, categorize, tag and share your precious memories through Autonomi. No middlemen needed for you to share with your family. No dropbox size limits for you pictures or videos. And no loss of control of your data just because you make it accessible to your loved ones.",
            "https://impossible-futures.com/projects/memories"
        );

        // 20
        appRegistry.registerApp(
            sender,
            "Mutant",
            "Decentralized P2P Storage with Mutable Key/Values. Pay once to grow your storage space, and mutate it at will for free forever. Can be used like Redis, Mongo, Dropbox, ... Modular design so you can use it in your applications, from the CLI directly, or from a Web frontend app",
            "https://impossible-futures.com/projects/mutant"
        );

        // 21
        appRegistry.registerApp(
            sender,
            "MyLife",
            "MyLife is the world's first nonprofit, AI-powered humanist digital legacy platform - where individuals collect, curate, and evolve their life stories as living digital legacies. It's part Library of Alexandria, part empathetic AI companion, part future-proof memorial - powered by MyLife and Autonomi",
            "https://impossible-futures.com/projects/mylife"
        );

        // 22
        appRegistry.registerApp(
            sender,
            "Nest",
            "Imagine you have a toy box. But instead of keeping it just at home, it's stored in a magical, super safe cloud where you can reach it from anywhere. This app is like that magical toy box - it remembers how your toys (files) are arranged in folders, even if you move them between your computer and your phone.",
            "https://impossible-futures.com/projects/nest"
        );

        // 23
        appRegistry.registerApp(
            sender,
            "News Site",
            "A censorship-resistant news platform where every article is permanently stored on the Autonomi network.",
            "https://impossible-futures.com/projects/news-site"
        );

        // 24
        appRegistry.registerApp(
            sender,
            "Perpetual",
            "Perpetual is a backend on Autonomi for anonymous, untraceable, permanent data. Provides immutable storage, account-free anonymity, modular REST API, scalable vault/streaming infra, tx logging,",
            "https://impossible-futures.com/projects/perpetual"
        );

        // 25
        appRegistry.registerApp(
            sender,
            "Personal Soundtrack",
            "Personal Soundtrack is the first AI-powered music recommendation engine that delivers the perfect song for every moment - tuned to your biometric signals, environment, and evolving personal preferences.",
            "https://impossible-futures.com/projects/personal-soundtrack"
        );

        // 26
        appRegistry.registerApp(
            sender,
            "Pirate Radio",
            "Pirate Radio is a decentralized industry onboarding and verification network that connects artists, studios, venues, and collaborators - removing the need for traditional labels and giving power back to the creators.",
            "https://impossible-futures.com/projects/pirate-radio"
        );

        // 27
        appRegistry.registerApp(
            sender,
            "Queeni AI Assistant",
            unicode"Queeni is like a smart little helper in your pocket. 📱 She knows when you have meetings, when you're hungry, when you forget something... and she helps you! 💡 She can search the internet, create tasks, remind you, and say: 'Hey, it's time to drink water!' 🚰She's your queen of the organized day! 👑",
            "https://impossible-futures.com/projects/queeni-ai-assistant"
        );

        // 28
        appRegistry.registerApp(
            sender,
            "REGRU",
            "REGRU is the world's first fully traceable and transparent online marketplace for regenerative food and fibre, connecting conscious customers to ethical businesses and farmers regenerating their land. A truly regenerative economy - powered by Autonomi.",
            "https://impossible-futures.com/projects/regru"
        );

        // 29
        appRegistry.registerApp(
            sender,
            "SafeStoreAPI",
            ".NET WebAPI Gateway to Autonomi's Infinite Storage. Step through a normal API... and enter a world without limits. Small server, big world. Data that lives forever.",
            "https://impossible-futures.com/projects/safestoreapi"
        );

        // 30
        appRegistry.registerApp(
            sender,
            "Screenshot Tool",
            "Capture What Matters - Instantly and Effortlessly. A lightweight, intuitive application designed to make taking screenshots easier than ever. Save your screenshots locally or upload them directly to the Autonomi network for fast and seamless sharing.",
            "https://impossible-futures.com/projects/screenshot-tool"
        );

        // 31
        appRegistry.registerApp(
            sender,
            "SOMA",
            "SOMA gives you complete ownership of your personal information through secure, private vaults. Whether you're moving countries or rebuilding after displacement, SOMA ensures your health records, identity, and essential documentation remain accessible, portable, and always under your control.",
            "https://impossible-futures.com/projects/soma"
        );

        // 32
        appRegistry.registerApp(
            sender,
            "STASHBAG",
            "Secure all your digital stuff with STASHBAG. Combining decentralized identity protocols with AI assisted services. What the Cashapp app did for financial ease of use and accessibility, the STASHBAG app will do for digital security and privacy. ",
            "https://impossible-futures.com/projects/stashbag"
        );

        // 33
        appRegistry.registerApp(
            sender,
            "Vessmere",
            "What if your online battles never had to end? Vessmere rethinks multiplayer with a serverless design, replacing fragile central servers. Uses direct P2P (WebRTC/libp2p) for fast-paced action & the Autonomi Network for persistent game/player data, creating a resilient, 'eternal' battleground no single entity can switch off.",
            "https://impossible-futures.com/projects/vessmere"
        ); */

        console.log("All apps successfully registered!");
    }
}
