using ArtDevops.Dialogs.Policy;
using ArtDevops.Dialogs.QnA;
using ArtDevops.Models;
using Microsoft.Bot.Builder;
using Microsoft.Bot.Builder.Dialogs;
using Microsoft.Bot.Builder.Dialogs.Choices;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace ArtDevops.Dialogs.Root
{
    public class RootDialog : ComponentDialog
    {
        private const string choicePromptName = "choiceprompt";
        private const string textPromptName = "textChoice";
        private IStatePropertyAccessor<GlobalUserState> _globalUserStateAccessor;
        private UserState _userState;

        public RootDialog(UserState userState) : base(nameof(RootDialog))
        {
            var waterfallSteps = new WaterfallStep[]
            {
                SayHiAsync,
                PromptForDialogAsync,
                HandleFlowResultAsync,
                EndAsync,
            };

            _userState = userState ?? throw new ArgumentNullException(nameof(userState));
            _globalUserStateAccessor = _userState.CreateProperty<GlobalUserState>(nameof(GlobalUserState));

            AddDialog(new WaterfallDialog(nameof(WaterfallDialog), waterfallSteps));
            AddDialog(new TextPrompt(textPromptName));
            AddDialog(new ChoicePrompt(choicePromptName));
            AddDialog(new PolicyDialog(userState));
            AddDialog(new InvoiceDialog(userState));
            AddDialog(new AccidentDialog(userState));
            AddDialog(new DeductibleDialog(userState));
            AddDialog(new QnADialog(userState));

            InitialDialogId = nameof(WaterfallDialog);
        }

        private async Task<DialogTurnResult> SayHiAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            var state = await _globalUserStateAccessor.GetAsync(stepContext.Context, () => new GlobalUserState());

            if (state.DidUserGaveName == false)
            {
                state.DidUserGaveName = true;
                return await stepContext.PromptAsync(textPromptName,
                    new PromptOptions
                    {
                        Prompt = stepContext.Context.Activity.CreateReply(RootStrings.Welcome)
                    });
            }
            else
            {
                await stepContext.Context.SendActivityAsync($"{RootStrings.WelcomeBack}", cancellationToken: cancellationToken);
                return await stepContext.NextAsync(cancellationToken: cancellationToken);
            }
        }

        private async Task<DialogTurnResult> PromptForDialogAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            var state = await _globalUserStateAccessor.GetAsync(stepContext.Context, () => new GlobalUserState());

            state.Name = (string.IsNullOrEmpty(state.Name)) ? stepContext.Result.ToString() : state.Name;

            return await stepContext.PromptAsync(choicePromptName,
                new PromptOptions
                {
                    Choices = ChoiceFactory.ToChoices(new List<string> { RootStrings.InvoiceChoice, RootStrings.PolicyChoice, RootStrings.DeductiblesChoice, RootStrings.AccidentChoice, RootStrings.QnAPrompt }),
                    Prompt = MessageFactory.Text($"{String.Format(RootStrings.WhichFlowPrompt, state.Name)}"),
                    RetryPrompt = MessageFactory.Text(RootStrings.InvalidChoice)
                },
                cancellationToken).ConfigureAwait(false);
        }

        private async Task<DialogTurnResult> HandleFlowResultAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            var result = ((FoundChoice)stepContext.Result).Value;

            if (result == RootStrings.PolicyChoice)
            {
                return await stepContext.BeginDialogAsync(nameof(PolicyDialog), cancellationToken);
            }
            else if (result == RootStrings.InvoiceChoice)
            {
                return await stepContext.BeginDialogAsync(nameof(InvoiceDialog), cancellationToken);
            }
            else if (result == RootStrings.DeductiblesChoice)
            {
                return await stepContext.BeginDialogAsync(nameof(DeductibleDialog), cancellationToken);
            }
            else if (result == RootStrings.AccidentChoice)
            {
                return await stepContext.BeginDialogAsync(nameof(AccidentDialog), cancellationToken);
            }
            else if (result == RootStrings.QnAPrompt)
            {
                return await stepContext.BeginDialogAsync(nameof(QnADialog), cancellationToken);
            }
            else
            {
                return await stepContext.NextAsync(cancellationToken: cancellationToken);
            }
        }

        private async Task<DialogTurnResult> EndAsync(WaterfallStepContext stepContext, CancellationToken cancellationToken)
        {
            return await stepContext.ReplaceDialogAsync(InitialDialogId, cancellationToken: cancellationToken).ConfigureAwait(false);
        }
    }
}
