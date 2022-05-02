<?php declare(strict_types=1);

namespace App\EventSubscriber;

use App\Entity\Syslog;
use Doctrine\Persistence\ManagerRegistry;
use SplObjectStorage;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Event\ConsoleCommandEvent;
use Symfony\Component\Console\Event\ConsoleErrorEvent;
use Symfony\Component\Console\Event\ConsoleTerminateEvent;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpKernel\Event\RequestEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\Event\TerminateEvent;

class SyslogEventSubscriber implements EventSubscriberInterface
{
    /** @var ManagerRegistry */
    private $registry;

    /** @var SplObjectStorage|array<Command, Syslog> */
    private $buffer;

    public function __construct(ManagerRegistry $registry)
    {
        $this->registry = $registry;
        $this->buffer = new SplObjectStorage();
    }

    public function onKernelRequest(RequestEvent $event): void
    {
        if (!$event->isMasterRequest()) {
            return;
        }

        $syslog = new Syslog();
        $syslog->setLevel('info');
        $syslog->merge([
            'start' => microtime(true),
        ]);

        $event->getRequest()->attributes->set('_syslog', $syslog);
    }

    public function onKernelResponse(ResponseEvent $event): void
    {
        if (!$event->isMasterRequest()) {
            return;
        }

        $syslog = $event->getRequest()->attributes->get('_syslog') ?? new Syslog();
        $syslog->setFacility('kernel');
        $syslog->setMessage($event->getRequest()->getHost() ? $event->getRequest()->getUri() : '???');
        $syslog->setXRequestId($event->getRequest()->headers->get('X-Request-Id'));
        $syslog->merge([
            'status_code' => $event->getResponse()->getStatusCode(),
        ]);

        if (!$syslog->getLevel()) {
            $syslog->setLevel('error');
        }

        if ($start = $syslog->get('start')) {
            $syslog->merge(['duration' => microtime(true) - $start]);
        }

        $this->persist($syslog);
    }

    public function onTerminate(TerminateEvent $event): void
    {
        $this->flush();
    }

    public function onConsoleCommand(ConsoleCommandEvent $event): void
    {
        if (!$event->getCommand()) {
            return ;
        }

        $syslog = new Syslog();
        $syslog->setLevel('info');
        $syslog->setFacility('console');
        $syslog->setMessage($event->getCommand()->getName());
        $syslog->merge(['start' => microtime(true)]);

        $this->buffer->offsetSet($event->getCommand(), $syslog);
    }

    public function onConsoleError(ConsoleErrorEvent $event): void
    {
        if (!$event->getCommand()) {
            return;
        }

        /** @var Syslog $syslog */
        $syslog = $this->buffer->offsetGet($event->getCommand()) ?? null;
        if ($syslog) {
            $syslog->setLevel('error');
        }
    }

    public function onConsoleTerminate(ConsoleTerminateEvent $event): void
    {
        foreach ($this->buffer as $key => $command) {
            $syslog = $this->buffer->offsetGet($command);

            if ($start = $syslog->get('start')) {
                $syslog->merge(['duration' => microtime(true) - $start]);
            }

            $this->persist($syslog);
            $this->buffer->offsetUnset($command);
        }

        $this->flush();
    }

    private function persist(Syslog $syslog): void
    {
        $this->registry->getManager()->persist($syslog);
    }

    private function flush(): void
    {
        if (!$this->registry->getConnection()->isConnected()) {
            return;
        }

        if (!$this->registry->getManager()->isOpen()) {
            return;
        }

        $this->registry->getManager()->flush();
    }

    public static function getSubscribedEvents(): array
    {
        return [
            RequestEvent::class => 'onKernelRequest',
            ResponseEvent::class => 'onKernelResponse',
            TerminateEvent::class => 'onTerminate',
            ConsoleCommandEvent::class => 'onConsoleCommand',
            ConsoleErrorEvent::class => 'onConsoleError',
            ConsoleTerminateEvent::class => 'onConsoleTerminate',
        ];
    }
}